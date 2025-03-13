using System;
using Newtonsoft.Json;

namespace runner_test;

public readonly struct Product
{
    public readonly string Name;
    public readonly DateTime Date;

    public Product(string name, DateTime date)
    {
        this.Name = name;
        this.Date = date;
    }
}

public static class Program
{
    public static void Main()
    {
        var product = new Product("Apple", new DateTime(2008, 12, 28));
        var json = JsonConvert.SerializeObject(product);

        Console.WriteLine(json);
    }
}
