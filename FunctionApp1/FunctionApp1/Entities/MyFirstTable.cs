using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FunctionApp1.Entities
{
    internal static class SQLTables
    {
        internal class MyFirstTable
        {
            public System.Guid Id { get; set; }
            public string Name { get; set; }
            public string Surname { get; set; }
        }
    }
}