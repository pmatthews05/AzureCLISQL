using Microsoft.Azure.Services.AppAuthentication;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Threading.Tasks;
using static FunctionApp1.Entities.SQLTables;

namespace FunctionApp1.HelperClass
{
    internal static class Database
    {
        static internal List<int> TransientErrorNumbers =
         new List<int> { 4060, 40197, 40501, 40613,
          49918, 49919, 49920, 11001 };

        internal static async Task<MyFirstTable> GetMyFirstTableItemByID(Guid id, ILogger log, int retryCount = 5, int delay = 500)
        {
            if (retryCount <= 0)
                throw new ArgumentException("Provide a retry count greater than zero.");

            if (delay <= 0)
                throw new ArgumentException("Provide a delay greater than zero.");

            log.LogInformation($"Obtain MyFirstTable information for ID:{id}");
            log.LogInformation("Retrieve Connection string");
            string sqlConnectionString = Utilities.GetConnectionString("SQLConnectionString");
            log.LogInformation("Retrieve Access Token");
            string accessToken = await GetSQLAccessToken(log);

            MyFirstTable myFirstTable = null;

            int retryAfterInterval = 0;
            int retryAttempts = 0;
            int backoffInterval = delay;

            while (retryAttempts < retryCount)
            {
                using (SqlConnection conn = new SqlConnection(sqlConnectionString))
                {
                    string statement = $"Select * from MyFirstTable Where Id=@id";

                    try
                    {
                        using (SqlCommand cmd = new SqlCommand(statement, conn))
                        {
                            cmd.Parameters.AddWithValue("Id", id);
                            conn.AccessToken = accessToken;
                            log.LogInformation("Connect to SQL");
                            await conn.OpenAsync();
                            log.LogInformation("Executing SQL Query");
                            using (SqlDataReader reader = await cmd.ExecuteReaderAsync())
                            {
                                if (reader.HasRows)
                                {
                                    while (reader.Read())
                                    {
                                        myFirstTable = new MyFirstTable()
                                        {
                                            Id = reader.GetGuid(reader.GetOrdinal("Id")),
                                            Name = reader.GetString(reader.GetOrdinal("Name")),
                                            Surname = reader.GetString(reader.GetOrdinal("Surname"))
                                        };
                                        break;
                                    }
                                }
                            }
                        }
                        break;
                    }
                    catch (SqlException sqlex)
                    {
                        if (TransientErrorNumbers.Contains(sqlex.Number) == true)
                        {
                            log.LogWarning($"{sqlex.Number}: transient occurred.");
                            retryAfterInterval = backoffInterval;
                            await Task.Delay(retryAfterInterval);
                            retryAttempts++;
                            backoffInterval *= 2;
                        }
                        else
                        {
                            log.LogError(sqlex.Message);
                            throw sqlex;
                        }

                    }
                    catch (Exception ex)
                    {
                        log.LogError(ex.Message);
                        throw ex;
                    }
                }
            }//End of While retry loop


            return myFirstTable;
        }

        internal async static Task<bool> DeleteAllItems(ILogger log, int retryCount = 5, int delay = 500)
        {
            if (retryCount <= 0)
                throw new ArgumentException("Provide a retry count greater than zero.");

            if (delay <= 0)
                throw new ArgumentException("Provide a delay greater than zero.");

            log.LogInformation("Retrieve Connection string");
            string sqlConnectionString = Utilities.GetConnectionString("SQLConnectionString");
            log.LogInformation("Retrieve Access Token");
            string accessToken = await GetSQLAccessToken(log);
            bool successful = false;

            int retryAfterInterval = 0;
            int retryAttempts = 0;
            int backoffInterval = delay;

            while (retryAttempts < retryCount)
            {
                using (SqlConnection conn = new SqlConnection(sqlConnectionString))
                {
                    string statement = $"Delete from MyFirstTable";

                    try
                    {
                        using (SqlCommand cmd = new SqlCommand(statement, conn))
                        {
                            conn.AccessToken = accessToken;
                            log.LogInformation("Connect to SQL");
                            await conn.OpenAsync();
                            log.LogInformation("Executing SQL Query");
                            int rowsAffected = cmd.ExecuteNonQuery();
                            if (rowsAffected > 0)
                            {
                                successful = true;
                            }
                        }
                        break;
                    }
                    catch (SqlException sqlex)
                    {
                        if (TransientErrorNumbers.Contains(sqlex.Number) == true)
                        {
                            log.LogWarning($"{sqlex.Number}: transient occurred.");
                            retryAfterInterval = backoffInterval;
                            await Task.Delay(retryAfterInterval);
                            retryAttempts++;
                            backoffInterval *= 2;
                        }
                        else
                        {
                            log.LogError(sqlex.Message);
                            throw sqlex;
                        }

                    }
                    catch (Exception ex)
                    {
                        log.LogError(ex.Message);
                        throw ex;
                    }
                }
            }//End of While retry loop


            return successful;
        }

        internal async static Task<bool> DeleteMyFirstTableItemByID(Guid id, ILogger log, int retryCount = 5, int delay = 500)
        {
            if (retryCount <= 0)
                throw new ArgumentException("Provide a retry count greater than zero.");

            if (delay <= 0)
                throw new ArgumentException("Provide a delay greater than zero.");

            log.LogInformation($"Delete MyFirstTable information for ID:{id}");
            log.LogInformation("Retrieve Connection string");
            string sqlConnectionString = Utilities.GetConnectionString("SQLConnectionString");
            log.LogInformation("Retrieve Access Token");
            string accessToken = await GetSQLAccessToken(log);
            bool successful = false;


            int retryAfterInterval = 0;
            int retryAttempts = 0;
            int backoffInterval = delay;

            while (retryAttempts < retryCount)
            {
                using (SqlConnection conn = new SqlConnection(sqlConnectionString))
                {
                    string statement = $"Delete from MyFirstTable Where Id=@id";

                    try
                    {
                        using (SqlCommand cmd = new SqlCommand(statement, conn))
                        {
                            cmd.Parameters.AddWithValue("Id", id);
                            conn.AccessToken = accessToken;
                            log.LogInformation("Connect to SQL");
                            await conn.OpenAsync();
                            log.LogInformation("Executing SQL Query");
                            int rowsAffected = cmd.ExecuteNonQuery();
                            if (rowsAffected > 0)
                            {
                                successful = true;
                            }
                        }
                        break;
                    }
                    catch (SqlException sqlex)
                    {
                        if (TransientErrorNumbers.Contains(sqlex.Number) == true)
                        {
                            log.LogWarning($"{sqlex.Number}: transient occurred.");
                            retryAfterInterval = backoffInterval;
                            await Task.Delay(retryAfterInterval);
                            retryAttempts++;
                            backoffInterval *= 2;
                        }
                        else
                        {
                            log.LogError(sqlex.Message);
                            throw sqlex;
                        }

                    }
                    catch (Exception ex)
                    {
                        log.LogError(ex.Message);
                        throw ex;
                    }
                }
            }//End of While retry loop


            return successful;
        }

        internal static async Task<bool> UpdateMyFirstTable(MyFirstTable myFirstTable, ILogger log, int retryCount = 5, int delay = 500)
        {
            if (retryCount <= 0)
                throw new ArgumentException("Provide a retry count greater than zero.");

            if (delay <= 0)
                throw new ArgumentException("Provide a delay greater than zero.");

            log.LogInformation($"Updating MyFirstTable information for ID:{myFirstTable.Id}");
            log.LogInformation("Retrieve Connection string");
            string sqlConnectionString = Utilities.GetConnectionString("SQLConnectionString");
            log.LogInformation("Retrieve Access Token");
            string accessToken = await GetSQLAccessToken(log);
            bool successful = false;


            int retryAfterInterval = 0;
            int retryAttempts = 0;
            int backoffInterval = delay;

            while (retryAttempts < retryCount)
            {
                try
                {
                    using (SqlConnection conn = new SqlConnection(sqlConnectionString))
                    {

                        string statement = $"UPDATE MyFirstTable SET Surname = @Surname, Name = @Name WHERE Id = @Id";

                        using (SqlCommand cmd = new SqlCommand(statement, conn))
                        {
                            cmd.Parameters.AddWithValue("Id", myFirstTable.Id);
                            cmd.Parameters.AddWithValue("Name", myFirstTable.Name);
                            cmd.Parameters.AddWithValue("Surname", myFirstTable.Surname);
                            conn.AccessToken = accessToken;
                            await conn.OpenAsync();
                            log.LogInformation("Executing SQL Query");
                            int rowsAffected = cmd.ExecuteNonQuery();
                            if (rowsAffected > 0)
                            {
                                successful = true;
                            }
                        }
                    }
                    break;
                }
                catch (SqlException sqlex)
                {
                    if (TransientErrorNumbers.Contains(sqlex.Number) == true)
                    {
                        log.LogWarning($"{sqlex.Number}: transient occurred.");
                        retryAfterInterval = backoffInterval;
                        await Task.Delay(retryAfterInterval);
                        retryAttempts++;
                        backoffInterval = backoffInterval * 2;
                    }
                    else
                    {
                        log.LogError(sqlex.Message);
                        throw sqlex;
                    }

                }
                catch (Exception ex)
                {
                    log.LogError(ex.Message);
                    throw ex;
                }
            }//End of While retry loop

            return successful;
        }

        internal static async Task<bool> CreateMyFirstTable(MyFirstTable myFirstTable, ILogger log, int retryCount = 5, int delay = 500)
        {
            if (retryCount <= 0)
                throw new ArgumentException("Provide a retry count greater than zero.");

            if (delay <= 0)
                throw new ArgumentException("Provide a delay greater than zero.");

            log.LogInformation($"Creating MyFirstTable information for ID:{myFirstTable.Id}");
            log.LogInformation("Retrieve Connection string");
            string sqlConnectionString = Utilities.GetConnectionString("SQLConnectionString");

            log.LogInformation("Retrieve Access Token");
            string accessToken = await GetSQLAccessToken(log);
            log.LogInformation("Got Access Token");
            bool successful = false;

            int retryAfterInterval = 0;
            int retryAttempts = 0;
            int backoffInterval = delay;

            while (retryAttempts < retryCount)
            {
                try
                {
                    using (SqlConnection conn = new SqlConnection(sqlConnectionString))
                    {

                        string statement = $"INSERT INTO MyFirstTable VALUES(@Id, @Name, @Surname)";

                        using (SqlCommand cmd = new SqlCommand(statement, conn))
                        {
                            cmd.Parameters.AddWithValue("Id", myFirstTable.Id);
                            cmd.Parameters.AddWithValue("Name", myFirstTable.Name);
                            cmd.Parameters.AddWithValue("Surname", myFirstTable.Surname);
                            conn.AccessToken = accessToken;
                            await conn.OpenAsync();
                            log.LogInformation("Executing SQL Query");
                            int rowsAffected = cmd.ExecuteNonQuery();
                            if (rowsAffected > 0)
                            {
                                successful = true;
                            }
                        }
                    }
                    break;
                }
                catch (SqlException sqlex)
                {
                    if (TransientErrorNumbers.Contains(sqlex.Number) == true)
                    {
                        log.LogWarning($"{sqlex.Number}: transient occurred.");
                        retryAfterInterval = backoffInterval;
                        await Task.Delay(retryAfterInterval);
                        retryAttempts++;
                        backoffInterval *= 2;
                    }
                    else
                    {
                        log.LogError(sqlex.Message);
                        throw sqlex;
                    }
                }
                catch (Exception ex)
                {
                    log.LogError(ex.Message);
                    throw ex;
                }
            }//End of While retry loop
            return successful;
        }

        private static async Task<string> GetSQLAccessToken(ILogger log)
        {
            AzureServiceTokenProvider tokenProvider = new AzureServiceTokenProvider();
            log.LogInformation("Geting Authentication Acess Token");
            return await tokenProvider.GetAccessTokenAsync($"https://database.windows.net/");
        }
    }
}
