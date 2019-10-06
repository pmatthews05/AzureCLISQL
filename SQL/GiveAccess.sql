IF USER_ID('<Username>') IS NULL
BEGIN
    CREATE USER [<Username>] FROM EXTERNAL PROVIDER;
END

ALTER ROLE db_datareader ADD MEMBER [<Username>];
ALTER ROLE db_datawriter ADD MEMBER [<Username>];