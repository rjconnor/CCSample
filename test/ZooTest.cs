using app.Domain;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace test
{
    [TestClass]
    public class ZooTest
    {
        [TestMethod]
        public void TestAnimalName()
        {
            var name = "tiddles";

            var cat = new Tiger { Name = name };

            Assert.IsTrue(string.Compare(name, cat.Name, true) == 0);
        }

        [TestMethod]
        public void TestAnimalNoise()
        {
            var name = "tiddles";

            var cat = new Tiger { Name = name };

            Assert.IsTrue(!string.IsNullOrWhiteSpace(cat.MakeNoise()));
        }
    }
}
