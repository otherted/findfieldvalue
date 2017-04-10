/* ***************************************************************************/
/* FINDFIELDVALUE_ORACLE.SQL                                                 */
/* Date: 04/06/2017                                                          */
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
/*        0 = Character  (CHAR,VARCHAR,VARCHAR2,NCHAR,NVARCHAR2)             */
/*        1 = Long Character  (LONG)                                         */
/*        2 = Number (NUMBER,FLOAT)                                          */
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
/*   09/26/2016 - Ted Lewis - Modify with option to return detail value data */
/*   09/28/2016 - Ted Lewis - Fix handling of long columns                   */
/*   04/06/2017 - Ted Lewis - New version using Oracle Catalog Tables        */
/*                            No longer PeopleSoft-specific                  */
/*                                                                           */
/* ***************************************************************************/

SET SERVEROUTPUT ON
SET PAGESIZE 0
SET LINESIZE 32000
SET TRIMSPOOL ON
SET TERMOUT ON
SET VERIFY OFF

PROMPT
PROMPT FINDFIELDVALUE_ORACLE.SQL
PROMPT Process Starting...
PROMPT

-- SETUP THE SPOOL FILE WHEN RUN THROUGH SQLPlus
SET TERMOUT OFF
col spoolname new_value spoolname;
select 'FINDFIELDVALUE_ORACLE_' || A.NAME || '_' || to_char(sysdate, 'yyyymmddhh24miss') || '.TXT' spoolname from v$database A; 
SPOOL C:\TEMP\&spoolname
SET TERMOUT ON
PROMPT 'Creating Output File: &spoolname';

-- ASK FOR INPUT PARAMETERS
PROMPT
PROMPT '-------------------------------------------------------------------------------'
PROMPT ' ENTER SEARCH VALUES INTO THE FOLLOWING PROMPTS.                               '
PROMPT ' ORACLE WILDCARDS ARE ACCEPTED AND WILL BE SUBSTITUTED IF VALUES NOT PROVIDED. '
PROMPT ' VALID VALUES FOR FIELD TYPE INCLUDE:                                          '
PROMPT '    0 = CHARACTER, 1 = LONG, 2 = NUMBER, OR LEAVE BLANK                        '
PROMPT '-------------------------------------------------------------------------------'
PROMPT
ACCEPT i_tabownerin    CHAR    PROMPT "Enter Schema or Owner:  "
ACCEPT i_fieldnamein   CHAR    PROMPT "Enter Field Name to Search:  "
ACCEPT i_fieldtypein   CHAR  DEFAULT "999" PROMPT "Enter Field Type:  "
ACCEPT i_fieldvaluein  CHAR    PROMPT "Enter Value to Find:  "
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

o_realtabowner  VARCHAR2(50);  

o_realrecname   varchar2(50);
o_realfldname   varchar2(50);
o_sqltablename  varchar2(50);
o_fieldtype     varchar2(20);
o_realvalue     long;   -- if searching long fields need a larger variable
o_rowcount      integer;

tabownerin      varchar(50);
fieldnamein     varchar(60);
fieldtypein     varchar(4);
fieldvaluein    varchar(500);
detailyesnoin   varchar(1);

str_recselect   VARCHAR2(1000);
str_dtlqry      VARCHAR2(500);
str_datatypecls VARCHAR2(250);
str_exclclause  VARCHAR2(500);

str_fieldtypes  VARCHAR(250);

err_num         NUMBER;
err_msg         VARCHAR2(256); 


PROCEDURE select_rec_summary IS
BEGIN
  -- build query to evaluate each record 
  -- dynamic sql is used to construct the query at run time since tablename, fieldname, etc are variables
  str_dtlqry := 
      'SELECT COUNT(*) ' ||
      'FROM ' || o_realtabowner || '.' || o_realrecname || ' A ' ||
      'WHERE UPPER(' || o_realfldname || ') LIKE :1 ';
  OPEN c_dtl FOR str_dtlqry USING fieldvaluein;
  LOOP
    FETCH c_dtl into o_rowcount;
    EXIT WHEN c_dtl%NOTFOUND;
    IF o_rowcount > 0 THEN
      -- row found containing search criteria, write to log
      n_recfound := n_recfound + 1;
      dbms_output.put_line(o_realtabowner || ' , ' || o_realrecname || ' , ' || o_realfldname || ' , ' || o_realvalue || ' , ' || o_rowcount || ' rows');
    END IF;
  END LOOP;
  CLOSE c_dtl;
EXCEPTION
  WHEN OTHERS THEN 
    err_num := SQLCODE;
    err_msg := SUBSTR(SQLERRM, 1, 200);
    dbms_output.put_line(o_realtabowner || ' , ' || o_realrecname || ' , ' || o_realfldname || ' , , ' || 'UNABLE TO PROCESS RECORD -- ' || err_msg);
END;    

PROCEDURE select_rec_detail IS
BEGIN
  -- build query to evaluate each record 
  -- dynamic sql is used to construct the query at run time since tablename, fieldname, etc are variables
  -- ALT - group results and count for each unique field value, provides more detail but runs much slower
  str_dtlqry := 
      'SELECT UPPER(' || o_realfldname || '), COUNT(*) ' ||
      'FROM ' || o_realtabowner || '.' || o_realrecname || ' A ' ||
      'WHERE UPPER(' || o_realfldname || ') LIKE :1 '  ||
      'GROUP BY UPPER(' || o_realfldname || ') ';
  OPEN c_dtl FOR str_dtlqry USING fieldvaluein;
  LOOP
    FETCH c_dtl into o_realvalue, o_rowcount;
    EXIT WHEN c_dtl%NOTFOUND;    
    -- row found containing search criteria, write to log
    n_recfound := n_recfound + 1;
    dbms_output.put_line(o_realtabowner || ' , ' || o_realrecname || ' , ' || o_realfldname || ' , ' || o_realvalue || ' , ' || o_rowcount || ' rows');    
  END LOOP;
  CLOSE c_dtl;
EXCEPTION
  WHEN OTHERS THEN 
    err_num := SQLCODE;
    err_msg := SUBSTR(SQLERRM, 1, 200);
    dbms_output.put_line(o_realtabowner || ' , ' || o_realrecname || ' , ' || o_realfldname || ' , , ' || 'UNABLE TO PROCESS RECORD -- ' || err_msg);
END;    


/* ********** BEGIN MAIN PROGRAM ********** */
BEGIN
  SELECT name into c_dbname FROM V$DATABASE;
  
  dbms_output.put_line('FINDFIELDVALUE_ORACLE.SQL');
  dbms_output.put_line(chr(10));
  dbms_output.put_line('Start Time: ' || TO_CHAR(SYSTIMESTAMP,'MM/DD/YYYY HH12:MI:SS AM'));
  dbms_output.put_line('Database: ' || c_dbname);
  dbms_output.put_line(chr(10));
  
  -- stage and validate input parameters
  tabownerin    := '&&i_tabownerin';
  fieldnamein   := '&&i_fieldnamein';
  fieldtypein   := '&&i_fieldtypein';
  fieldvaluein  := '&&i_fieldvaluein';
  detailyesnoin := '&&i_detailyesnoin';
  
  tabownerin    := upper(tabownerin);
  fieldnamein   := upper(fieldnamein);
  fieldtypein   := upper(fieldtypein);
  fieldvaluein  := upper(fieldvaluein);
  detailyesnoin := upper(detailyesnoin);
  
  IF tabownerin IS NULL THEN
    tabownerin := '%';
  END IF;
  IF fieldnamein IS NULL THEN
    fieldnamein := '%';
  END IF;
  IF fieldvaluein IS NULL THEN
    fieldvaluein := '%';
  END IF;
  IF detailyesnoin IS NULL OR detailyesnoin <> 'Y' THEN
    detailyesnoin := 'N';
  END IF;
  
  CASE  
    WHEN fieldtypein = '0' THEN
       str_fieldtypes := '''CHAR'',''VARCHAR'',''VARCHAR2'',''NCHAR'',''NVARCHAR2''';
       str_datatypecls := 'AND C.DATA_TYPE IN ( ' || str_fieldtypes || ') ';
    WHEN fieldtypein = '1' THEN
       str_fieldtypes := '''LONG''';
       str_datatypecls := 'AND C.DATA_TYPE = ' || str_fieldtypes || ' ';
    WHEN fieldtypein = '2' THEN
       str_fieldtypes := '''FLOAT'',''NUMBER''';
       str_datatypecls := 'AND C.DATA_TYPE IN ( ' || str_fieldtypes || ') ';
    WHEN fieldtypein = '999' THEN
       str_fieldtypes := '''CHAR'',''VARCHAR'',''VARCHAR2'',''NCHAR'',''NVARCHAR2'',''LONG'',''FLOAT'',''NUMBER''';
       str_datatypecls := 'AND C.DATA_TYPE IN ( ' || str_fieldtypes || ') ';
    ELSE
       str_fieldtypes := ' ';
       str_datatypecls := ' ';
  END CASE;
  
  -- add additional clause here as required, for example to exclude some records from the search
  str_exclclause := ' ';  
  
  -- output search parameterss
  dbms_output.put_line('Schema Name Search = ' || tabownerin);
  dbms_output.put_line('Field Name Search = ' || fieldnamein);
  dbms_output.put_line('Field Type Search = ' || str_fieldtypes);
  dbms_output.put_line('Field Value Search = ' || fieldvaluein);
  dbms_output.put_line('Output Detail Values = ' || detailyesnoin);
  -- the detail processing procedures cannot handle long colums due to group by, issue warning
  IF detailyesnoin = 'Y' AND (fieldtypein = '1' OR fieldtypein = '999') THEN
    dbms_output.put_line(chr(255)||chr(255)||chr(255)||'WARNING: Detail output not available for tables with LONG columns...');
    dbms_output.put_line(chr(255)||chr(255)||chr(255)||'         Only summary counts will be provided for those records.    ');
  END IF;
  dbms_output.put_line(chr(10));
  
  dbms_output.put_line(chr(10));
  dbms_output.put_line('OWNERNAME , RECORDNAME , FIELDNAME , FIELD VALUE , ROW COUNT');
  dbms_output.put_line('-------------------------------------------------');
  
  n_recproc := 0;  -- global variable for counting number of records attempted
  n_recfound := 0;  -- global variable for counting number of hits found in the records
  
  -- BUILD THE QUERY TO SELECT ALL RECORDS THAT CONTAIN THE FIELD(S) TO SEARCH
  str_recselect := 
      'SELECT 
       C.OWNER
       ,C.TABLE_NAME
       ,C.COLUMN_NAME
       ,C.DATA_TYPE
       FROM ALL_TABLES T, ALL_TAB_COLUMNS C
       WHERE UPPER(T.OWNER) LIKE UPPER(:tabownerin)
       AND UPPER(C.COLUMN_NAME) LIKE UPPER(:fieldnamein)
       AND C.TABLE_NAME = T.TABLE_NAME
       AND C.OWNER = T.OWNER '
       || str_datatypecls || 
       ' AND (((C.DATA_LENGTH + NVL(DATA_SCALE,0) + 2) >= LENGTH(:fieldvaluein)) or (C.DATA_LENGTH = 0)) '
       || str_exclclause || 
       ' ORDER BY T.TABLE_NAME, C.COLUMN_NAME ';

  OPEN c_recselect FOR str_recselect USING tabownerin, fieldnamein, fieldvaluein;   
  LOOP
    FETCH c_recselect INTO  o_realtabowner, o_realrecname, o_realfldname, o_fieldtype; 
    EXIT WHEN c_recselect%NOTFOUND;
    n_recproc := n_recproc + 1;
    
    IF detailyesnoin = 'N' OR o_fieldtype = 'LONG' THEN
      -- do summary processing if selected, or if this is a LONG column do summary because group by will cause detail process to fail
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

