using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FunctionApp1.Entities
{
    public class GetIDEntity
    {
        [JsonProperty(PropertyName = "ID")]
        public Guid Id { get; set; }
    }
}
