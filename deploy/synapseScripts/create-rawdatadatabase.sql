CREATE DATABASE db1
GO
USE db1
GO
-- TODO: Make sure that the connectionstring to the datalake container that contains the raw messages is
--       correct. We also assume that the hierarchy/folder structure within this container is
--       year={YYYY}/month={YYYY}{MM}/date={YYYY}{MM}{DD}
--       Be aware that the fileparts are case-sensitive!
-- OBS: Be sure to replace <datalakeUniqueName> before running.
DROP VIEW IF EXISTS telemetrydata
GO
CREATE VIEW telemetrydata
AS
-- Unfortunately, FORMAT = 'json' is not a recognized option. Instead, we use set the field terminator and
-- field quote to vertical tab ('0x0b'). Vertical tab must never occur in the raw data. It is set only to
-- override the default values and make OPENROWSET parse the json as a csv with one column and multiple lines.
    SELECT *, rows.filepath(1) as [Year], rows.filepath(2) AS [Month], rows.filepath(3) AS [Date]
    FROM OPENROWSET(
        BULK 'https://<datalakeUniqueName>.blob.core.windows.net/telemetry-rawdata/year=*/month=*/date=*/*.json',
        FORMAT = 'csv',
        FIELDTERMINATOR ='0x0b',
        FIELDQUOTE = '0x0b'
    ) WITH (doc nvarchar(max)) AS rows
GO

-- Create the view that works on the parquet - data
-- Unfortunately, automatic schema-inferring inspects the schema of the first file, and uses that schema.
-- It doesn't look at the schema's of all the files and combines them. Therefore, we use the WITH clause.
-- OBS: Be sure to replace <datalakeUniqueName> before running.
DROP VIEW IF EXISTS parquetdata
GO
CREATE VIEW parquetdata
AS
    SELECT r.filepath(1) as device, *
    FROM OPENROWSET(
        BULK 'https://<datalakeUniqueName>.blob.core.windows.net/parquet-contents/device=*/*.parquet',
        FORMAT = 'parquet'
    ) 
    with(
        [deviceId] VARCHAR(50),
        [timestamp] DATETIME,
        [temp] FLOAT,
        [humidity] FLOAT,
        [size] FLOAT,
        [flux] FLOAT,
        [current] FLOAT,
        [voltage] FLOAT,
        [ph] FLOAT,
        [lumen] FLOAT
    )
    as r


