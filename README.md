# findfieldvalue
PL/SQL Script that will allow you to search for a value in all tables and fields within the PeopleSoft database.  

This script works for ORACLE environments.  
There is also an SQR version, but the functionality is more limited.    

# Running the Script:
SQL*Plus:
1. Open SQL*Plus and login to database
2. Run script  (ex. @findfieldvalue.sql)
3. You will be prompted for the input values

SQL Developer:
1. Open SQL Developer and connect to database
2. Open File
3. Run as script
4. Prompt entry dialog will open.  Enter values for each prompt.  


# Inputs:
Field Name: Provide a field name or use wildcards

Field Type:
It is recommended to supply a value to avoid data type errors.
Leave blank to search all types.
  0 = Character
  1 = Long Character
  2 = Number   
  3 = Signed Number
  4 = Date 
  5 = Time  (support unknown)
  6 = DateTimestamp  (support unknown)
  8 = Image (uses raw BLOB, search not supported) 
  9 = Image Reference (name of image object, varchar2(30)
  
Field Value: Value to search for, can use % wildcard 

Return Detail Values: Yes (Y) or No (N)
  Yes - Return each distinct variation of the search value that is
        found, includes count of how many times that value exists.
        Not possible on records with LONG columns so those will
        default to only summary output.
  No - Only count the instances of the search value that are found

  The option to return each distinct variation of the search value found in the tables is done using a GROUP BY clause and provides much more detailed data, but the program will run much slower. Use with caution for large searches.
  
# Output:
File is created listing the table and field where value was found.
File is located under C:\Temp\.
