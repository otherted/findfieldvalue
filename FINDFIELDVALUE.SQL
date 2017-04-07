/* ***************************************************************************/
/* FINDFIELDVALUE.SQL                                                    */
/* Date: 7/27/2016                                                           */
/* Developer: Ted Lewis                                                      */
/* ------------------------------------------------------------------------- */
/* Description: Find tables that contain a specific field and value.         */
/*                                                                           */
/* Output: File is created listing tables.                                   */
/*                                                                           */
/* Input:                                                                    */
/*    Field Name:                                                            */
/*        Provide field name or use % wildcard for all fields                */
/*    Field Type:                                                            */
/*        Select a type or leave blank to search all types                   */
/*        Although recommended to supply value to avoid data type error      */
/*        0 = Character                                                      */
/*        1 = Long Character                                                 */
/*        2 = Number                                                         */
/*        3 = Signed Number                                                  */
/*        4 = Date                                                           */
/*        5 = Time                                                           */
/*        6 = DateTimep                                                      */
/*        8 = Image (uses raw BLOB, search not supported)                    */
/*        9 = Image Reference (name of image object, varchar2(30))           */
/*    Field Value:                                                           */
/*        Value to search for, can use % wildcard                            */
/*    Return Detail Values: Yes (Y) or No (N)                                */
/*        Yes - Return each distinct variation of the search value that is   */
/*              found, includes count of how many times that value exists.   */
/*              Not possible on records with LONG columns so those will      */
/*              default to only summary output.                              */
/*        No - Only count the instances of the search value that are found   */    
/*                                                                           */
/*   This version of the program includes the option to return each distinct */
/*   variation of the search value found in the tables. This is done using a */
/*   group by clause and provides much more detailed data, but the program   */
/*   will run much slower. Use with caution for large searches.              */
/*                                                                           */
/* ***************************************************************************/
/* History:                                                                  */
/*   07/27/2016 - Ted Lewis - Initial Creation                               */
/*                Based on find_field_value.sqr and fafv.sql                 */
/*   09/26/2016 - Ted Lewis - Modify with option to return detail value data */
/*   09/28/2016 - Ted Lewis - Fix handling of long columns                   */
/*   04/06/2017 - Ted Lewis - Add option for returning only key fields       */
/*                                                                           */
/* ***************************************************************************/

SET SERVEROUTPUT ON
SET PAGESIZE 0
SET LINESIZE 32000
SET TRIMSPOOL ON
SET TERMOUT ON
SET VERIFY OFF

PROMPT
PROMPT FINDFIELDVALUE.SQL
PROMPT Process Starting...
PROMPT

-- SETUP THE SPOOL FILE WHEN RUN THROUGH SQLPlus
SET TERMOUT OFF
col spoolname new_value spoolname;
select 'FINDFIELDVALUE_' || A.NAME || '_' || to_char(sysdate, 'yyyymmddhh24miss') || '.TXT' spoolname from v$database A; 
SPOOL C:\TEMP\&spoolname
SET TERMOUT ON
PROMPT 'Creating Output File: &spoolname';

-- ASK FOR INPUT PARAMETERS
PROMPT
PROMPT '-------------------------------------------------------------------------------'
PROMPT ' ENTER SEARCH VALUES INTO THE FOLLOWING PROMPTS.                               '
PROMPT ' ORACLE WILDCARDS ARE ACCEPTED AND WILL BE SUBSTITUTED IF VALUES NOT PROVIDED. '
PROMPT ' VALID VALUES FOR FIELD TYPE INCLUDE:                                          '
PROMPT '    0 = CHARACTER, 1 = LONG, 2 = NUMBER, 3 = SIGNED NUMBER, OR LEAVE BLANK     '
PROMPT '-------------------------------------------------------------------------------'
PROMPT
ACCEPT i_fieldnamein   CHAR    PROMPT "Enter Field Name to Search:  "
ACCEPT i_fieldtypein   CHAR  DEFAULT "999" PROMPT "Enter Field Type:  "
ACCEPT i_fieldvaluein  CHAR    PROMPT "Enter Value to Find:  "
ACCEPT i_fieldkeyin    CHAR  DEFAULT "N"  PROMPT "Only Key Fields? (Y/N):  "
ACCEPT i_detailyesnoin CHAR  DEFAULT "N"  PROMPT "Return Detail Values? (Y/N):  " 
PROMPT     


-- BEGIN PL/SQL CODING TO SEARCH DATABASE
-- START HERE IF RUNNING INTERACTIVELY IN TOAD OR SQLDeveloper
DECLARE
TYPE recCurType IS REF CURSOR;
c_recselect     recCurType;
c_dtl           recCurType;

c_dbname        varchar2(8);
n_recproc       integer;
n_recfound      integer;

o_realrecname   varchar2(50);
o_realfldname   varchar2(50);
o_sqltablename  varchar2(50);
o_fieldtype     integer;
--o_realvalue     varchar2(300);  -- maximum char in peoplesoft is 254
o_realvalue     long;   -- if searching long fields need a larger variable
o_rowcount      integer;

fieldnamein     varchar(60);
fieldtypein     varchar(4);
fieldvaluein    varchar(500);
fieldkeyin      varchar(1);
detailyesnoin   varchar(1);

str_recselect   VARCHAR2(1000);
str_keyonly     VARCHAR2(250);
str_dtlqry      VARCHAR2(500);

err_num         NUMBER;
err_msg         VARCHAR2(256); 


PROCEDURE select_rec_summary IS
BEGIN
  -- build query to evaluate each record 
  -- dynamic sql is used to construct the query at run time since tablename, fieldname, etc are variables
  str_dtlqry := 
      'SELECT COUNT(*) ' ||
      'FROM SYSADM.' || o_realrecname || ' A ' ||
      'WHERE UPPER(' || o_realfldname || ') LIKE :1 ';
  OPEN c_dtl FOR str_dtlqry USING fieldvaluein;
  LOOP
    FETCH c_dtl into o_rowcount;
    EXIT WHEN c_dtl%NOTFOUND;
    IF o_rowcount > 0 THEN
      -- row found containing search criteria, write to log
      n_recfound := n_recfound + 1;
      dbms_output.put_line(o_realrecname || ' , ' || o_realfldname || ' , ' || o_realvalue || ' , ' || o_rowcount || ' rows');
    END IF;
  END LOOP;
  CLOSE c_dtl;
EXCEPTION
  WHEN OTHERS THEN 
    err_num := SQLCODE;
    err_msg := SUBSTR(SQLERRM, 1, 200);
    dbms_output.put_line(o_realrecname || ' , ' || o_realfldname || ' , , ' || 'UNABLE TO PROCESS RECORD -- ' || err_msg);
END;    

PROCEDURE select_rec_detail IS
BEGIN
  -- build query to evaluate each record 
  -- dynamic sql is used to construct the query at run time since tablename, fieldname, etc are variables
  -- ALT - group results and count for each unique field value, provides more detail but runs much slower
  str_dtlqry := 
      'SELECT UPPER(' || o_realfldname || '), COUNT(*) ' ||
      'FROM SYSADM.' || o_realrecname || ' A ' ||
      'WHERE UPPER(' || o_realfldname || ') LIKE :1 '  ||
      'GROUP BY UPPER(' || o_realfldname || ') ';
  OPEN c_dtl FOR str_dtlqry USING fieldvaluein;
  LOOP
    FETCH c_dtl into o_realvalue, o_rowcount;
    EXIT WHEN c_dtl%NOTFOUND;    
    -- row found containing search criteria, write to log
    n_recfound := n_recfound + 1;
    dbms_output.put_line(o_realrecname || ' , ' || o_realfldname || ' , ' || o_realvalue || ' , ' || o_rowcount || ' rows');    
  END LOOP;
  CLOSE c_dtl;
EXCEPTION
  WHEN OTHERS THEN 
    err_num := SQLCODE;
    err_msg := SUBSTR(SQLERRM, 1, 200);
    dbms_output.put_line(o_realrecname || ' , ' || o_realfldname || ' , , ' || 'UNABLE TO PROCESS RECORD -- ' || err_msg);
END;    


/* ********** BEGIN MAIN PROGRAM ********** */
BEGIN
  SELECT name into c_dbname FROM V$DATABASE;
  
  dbms_output.put_line('FINDFIELDVALUE.SQL');
  dbms_output.put_line(chr(10));
  dbms_output.put_line('Start Time: ' || TO_CHAR(SYSTIMESTAMP,'MM/DD/YYYY HH12:MI:SS AM'));
  dbms_output.put_line('Database: ' || c_dbname);
  dbms_output.put_line(chr(10));
  
  -- stage and validate input parameters
  fieldnamein   := '&&i_fieldnamein';
  fieldtypein   := '&&i_fieldtypein';
  fieldvaluein  := '&&i_fieldvaluein';
  fieldkeyin    := '&&i_fieldkeyin';
  detailyesnoin := '&&i_detailyesnoin';
  
  fieldnamein   := upper(fieldnamein);
  fieldtypein   := upper(fieldtypein);
  fieldvaluein  := upper(fieldvaluein);
  fieldkeyin    := upper(fieldkeyin);
  detailyesnoin := upper(detailyesnoin);
  
  IF fieldnamein IS NULL THEN
    fieldnamein := '%';
  END IF;
  IF fieldtypein = '999' THEN
    fieldtypein := '%';
  END IF;
  IF fieldvaluein IS NULL THEN
    fieldvaluein := '%';
  END IF;
  IF fieldkeyin IS NULL OR fieldkeyin <> 'Y' THEN
    fieldkeyin := 'N';
  END IF;
  IF detailyesnoin IS NULL OR detailyesnoin <> 'Y' THEN
    detailyesnoin := 'N';
  END IF;
  
  -- output search parameterss
  dbms_output.put_line('Field Name Search = ' || fieldnamein);
  dbms_output.put_line('Field Type Search = ' || fieldtypein);
  dbms_output.put_line('Field Value Search = ' || fieldvaluein);
  dbms_output.put_line('Only Key Fields = ' || fieldvaluein);
  dbms_output.put_line('Output Detail Values = ' || detailyesnoin);
  -- the detail processing procedures cannot handle long colums due to group by, issue warning
  IF detailyesnoin = 'Y' AND (fieldtypein = '1' OR fieldtypein = '%') THEN
    dbms_output.put_line(chr(255)||chr(255)||chr(255)||'WARNING: Detail output not available for tables with LONG columns...');
    dbms_output.put_line(chr(255)||chr(255)||chr(255)||'         Only summary counts will be provided for those records.    ');
  END IF;
  dbms_output.put_line(chr(10));
  
  dbms_output.put_line(chr(10));
  dbms_output.put_line('RECORDNAME , FIELDNAME , FIELD VALUE , ROW COUNT');
  dbms_output.put_line('-------------------------------------------------');
  
  n_recproc := 0;  -- global variable for counting number of records attempted
  n_recfound := 0;  -- global variable for counting number of hits found in the records
  
  -- if only returning key fields then build clause for that
  IF fieldkeyin = 'Y' THEN
    str_keyonly := 'AND bitand(RF.USEEDIT, 1) > 0';
  ELSE
    str_keyonly := ' ';
  END IF;
  
  -- BUILD THE QUERY TO SELECT ALL RECORDS THAT CONTAIN THE FIELD(S) TO SEARCH
  str_recselect := 
      'SELECT 
         RF.RECNAME
       , RF.FIELDNAME
       , RD.SQLTABLENAME
       , F.FIELDTYPE
       FROM SYSADM.PSRECFIELDDB RF, SYSADM.PSRECDEFN RD, SYSADM.PSDBFIELD F
       WHERE RF.FIELDNAME LIKE UPPER(:fieldnamein)
       AND RD.RECNAME = RF.RECNAME
       AND RD.RECTYPE = 0  -- ONLY CHECK SQL TABLES
       AND RF.FIELDNAME = F.FIELDNAME
       AND F.FIELDTYPE LIKE :fieldtypein
       AND F.FIELDTYPE <> 8  -- exclue IMAGE fields which are binary BLOB
       AND (((F.LENGTH + F.DECIMALPOS + 2) >= length(:fieldvaluein)) 
            OR (F.LENGTH = 0))'
       || str_keyonly ||
       'AND RD.RECNAME NOT IN (''HR_ACCTG_LINE'',''VCHR_ACCTG_LINE'')  -- *** exclude certain records as required ***
       ORDER BY RF.RECNAME, RF.FIELDNAME';    

  OPEN c_recselect FOR str_recselect USING fieldnamein, fieldtypein, fieldvaluein;   
  LOOP
    FETCH c_recselect INTO  o_realrecname, o_realfldname, o_sqltablename, o_fieldtype; 
    EXIT WHEN c_recselect%NOTFOUND;
    n_recproc := n_recproc + 1;
    
    IF o_sqltablename = ' ' THEN
      o_realrecname := 'PS_' || o_realrecname;
    ELSE
      o_realrecname := o_sqltablename;
    END IF;
    
    IF detailyesnoin = 'N' OR o_fieldtype = 1 THEN
      -- do summary processing if selected, or if this is a LONG column that will cause group by to fail
      select_rec_summary;
    ELSE
      -- do detail processing procedures
      select_rec_detail;
    END IF;
    
  END LOOP;
  CLOSE c_recselect;
  
  dbms_output.put_line(chr(10));
  dbms_output.put_line('Records Processed: ' || n_recproc);
  dbms_output.put_line('Records Found: ' || n_recfound);
  dbms_output.put_line(chr(10));
  dbms_output.put_line('End Time: ' || TO_CHAR(SYSTIMESTAMP,'MM/DD/YYYY HH12:MI:SS AM'));
  dbms_output.put_line('Process Complete!');
  
END;
/

SPOOL OFF;

