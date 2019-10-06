using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using FunctionApp1.Entities;
using FunctionApp1.HelperClass;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using static FunctionApp1.Entities.SQLTables;

namespace FunctionApp1
{
    public static class Function1
    {
        [FunctionName("AddPreSetData")]
        public static async Task<HttpResponseMessage> RunAddPreSetDataAsync([HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)]HttpRequestMessage req, ILogger log)
        {
            log.LogInformation("Add Data was Triggerd");

            List<MyFirstTable> CollectionOfNames = GetCollectionOfNames();
            try
            {
                foreach (var mft in CollectionOfNames)
                {
                    log.LogInformation($"Adding {mft.Name} {mft.Surname} to database");
                    await Database.CreateMyFirstTable(mft, log);
                }
            }
            catch (Exception ex)
            {
                log.LogError(ex.Message);
                return req.CreateResponse(HttpStatusCode.InternalServerError, $"Error Message:{ex.Message}");
            }

            return new HttpResponseMessage(HttpStatusCode.OK);
        }

        [FunctionName("GetById")]
        public static async Task<HttpResponseMessage> RunGetByIdAsync([HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)]HttpRequestMessage req, ILogger log)
        {
            string content = await req.Content.ReadAsStringAsync();
            log.LogInformation($"Received following payload: {content}");

            GetIDEntity GetContent = JsonConvert.DeserializeObject<GetIDEntity>(content);

            try
            {
                log.LogInformation("Checking Database for Id");
                MyFirstTable tableItem = await Database.GetMyFirstTableItemByID(GetContent.Id, log);
                return req.CreateResponse(HttpStatusCode.OK, $"Found item Id:{tableItem.Id} Name:{tableItem.Name} Surname:{tableItem.Surname}");
            }
            catch (Exception ex)
            {
                log.LogError(ex.Message);
                return req.CreateResponse(HttpStatusCode.InternalServerError, $"Error Message:{ex.Message}");
            }

        }

        [FunctionName("DeleteAllItems")]
        public static async Task<HttpResponseMessage> DeleteAllItems([HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)]HttpRequestMessage req, ILogger log)
        {
            log.LogInformation($"Calling Delete All Items function");

            try
            {
                log.LogInformation("Checking Database for Id");
                await Database.DeleteAllItems(log);
                return req.CreateResponse(HttpStatusCode.OK, $"Successfully deleted all items.");
            }
            catch (Exception ex)
            {
                log.LogError(ex.Message);
                return req.CreateResponse(HttpStatusCode.InternalServerError, $"Error Message:{ex.Message}");
            }

        }

        private static List<MyFirstTable> GetCollectionOfNames()
        {
            List<MyFirstTable> collection = new List<MyFirstTable>()
            {
                new MyFirstTable{ Id = new Guid("D60E1B14-D49E-4637-AD20-D0CA07EDEE80"), Name="Paul",   Surname="Matthews" },
                new MyFirstTable{ Id = new Guid("5AF3E272-B7AD-49E9-AD05-2EE01E200C04"), Name="Steven", Surname="Jones"    },
                new MyFirstTable{ Id = new Guid("235C742E-79B5-468E-8ECD-2C8FF69AA748"), Name="Donna",  Surname="Meier"    },
                new MyFirstTable{ Id = new Guid("DF65528E-3172-4132-B918-6F169EDD1D05"), Name="Kerry",  Surname="Williams" },
                new MyFirstTable{ Id = new Guid("C784757E-2D5D-4FF2-A725-DB79EC97707B"), Name="John",   Surname="Jones"    },
                new MyFirstTable{ Id = new Guid("FDFAF05D-68F6-4D16-9B51-958A3303B029"), Name="Pat" ,   Surname="Howard"   },
                new MyFirstTable{ Id = new Guid("59C50C16-00BB-4D2C-BEDE-F1F8A56F5FF0"), Name="Yusif",  Surname="Wazha"    },
                new MyFirstTable{ Id = new Guid("F8550149-AEAA-4FE5-BEBB-7B5AD7180BA3"), Name="David",  Surname="Jones"    }
            };

            return collection;
        }
    }
}
