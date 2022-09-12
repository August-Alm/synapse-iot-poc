-- Create a contained user in Synapse for an Azure Function
-- https://docs.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?tabs=azure-powershell
-- The <funcUniqueName> must be the same name as the Azure FunctionApp.
USE db1
CREATE USER [<funcUniqueName>] FROM EXTERNAL PROVIDER;

ALTER ROLE db_datareader ADD MEMBER [<funcUniqueName>];

GRANT ADMINISTER DATABASE BULK OPERATIONS TO [<funcUniqueName>]


-- Execute the below commands if you want to be able to login to Synapse with
-- your own credentials.  (The e-mail address must be known in Azure AD)
-- USE MASTER
-- CREATE LOGIN [your-emailaddress] FROM EXTERNAL PROVIDER;

-- USE db1
--CREATE USER [your-emailaddress] FROM EXTERNAL PROVIDER;