using System;
using System.Collections.Generic;
using System.Data;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;
using Microsoft.Data.SqlClient;
using Newtonsoft.Json;

namespace RawDataProcessor
{
    internal class RawTelemetryReader
    {
        private readonly string _connectionString;

        internal RawTelemetryReader(string connectionString)
        {
            _connectionString = connectionString;
        }

        internal async Task<IEnumerable<TelemetryItem>> ReadRawTelemetryRecordsSinceAsync(DateTimeOffset fromDate)
        {
            var telemetryItems = new List<TelemetryItem>();
            using (var connection = new SqlConnection(_connectionString))
            {
                connection.AccessToken = (await GetDatabaseAccessTokenAsync()).Token;
                connection.Open();

                string query = "SELECT * \n" +
                               "FROM telemetrydata \n" +
                               "WHERE year >= @p_Year AND month= @p_Month AND date >= @p_Date \n" +
                               "AND JSON_VALUE(doc, '$.EnqueuedTimeUtc') > @p_LastRunDate \n" +
                               "ORDER BY JSON_VALUE(doc, '$.EnqueuedTimeUtc')";

                var command = new SqlCommand(query);
                command.Connection = connection;
                command.Parameters.Add("@p_Year", SqlDbType.Int).Value = fromDate.Year;
                command.Parameters.Add("@p_Month", SqlDbType.Int).Value = Convert.ToInt32(fromDate.ToString("yyyyMM"));
                command.Parameters.Add("@p_Date", SqlDbType.Date).Value = fromDate.Date;
                command.Parameters.Add("@p_LastRunDate", SqlDbType.DateTimeOffset).Value = fromDate;

                using (var reader = await command.ExecuteReaderAsync())
                {
                    while (reader.Read())
                    {
                        var item = JsonConvert.DeserializeObject<TelemetryItem>(Convert.ToString(reader[0]));
                        telemetryItems.Add(item);
                    }
                    reader.Close();
                }
            }
            return telemetryItems;
        }

        private static async Task<AccessToken> GetDatabaseAccessTokenAsync()
        {
            return await new DefaultAzureCredential().GetTokenAsync(
                new TokenRequestContext(new[] { "https://database.windows.net/.default" }));
        }
    }
}