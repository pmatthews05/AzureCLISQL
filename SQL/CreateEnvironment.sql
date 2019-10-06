-- --------------------------------------------------
-- Creating all tables
-- --------------------------------------------------
if not exists (select * from INFORMATION_SCHEMA.TABLES where TABLE_Name = N'MyFirstTable')
BEGIN
    CREATE TABLE MyFirstTable (
        [Id]        uniqueidentifier       NOT NULL,
        [Name]      nvarchar(max)          NOT NULL,
        [Surname]   nvarchar(max)          NOT NULL
);

ALTER TABLE MyFirstTable
ADD CONSTRAINT [PK_MyFirstTable]
    PRIMARY KEY CLUSTERED ([Id] ASC);
END