using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace app.Domain
{
    public class Tiger
    {
        public string Name { get; set; }

        public string MakeNoise()
        {
            return "Meow";
        }
    }
}
