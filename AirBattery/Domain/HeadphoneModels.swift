import Foundation

func getHeadphoneModel(_ model: String) -> String {
    switch model {
    case "2002":
        return "Airpods"
    case "200e":
        return "Airpods Pro"
    case "200a", "201f":
        ///200a: Lightning
        ///201f: USB-C
        return "Airpods Max"
    case "200f":
        return "Airpods 2"
    case "2013":
        return "Airpods 3"
    case "201B", "2019":
        ///201B: ANC
        ///2019: no ANC
        return "Airpods 4"
    case "2014", "2024":
        ///2014: Lightning Case
        ///2024: USB-C Case
        return "Airpods Pro 2"
    case "2003":
        return "PowerBeats 3"
    case "200d":
        return "PowerBeats 4"
    case "200b":
        return "PowerBeats Pro"
    case "200c":
        return "Beats Solo Pro"
    case "2011":
        return "Beats Studio Buds"
    case "2010":
        return "Beats Flex"
    case "2005":
        return "BeatsX"
    case "2006":
        return "Beats Solo 3"
    case "2009":
        return "Beats Studio 3"
    case "2017":
        return "Beats Studio Pro"
    case "2012":
        return "Beats Fit Pro"
    case "2016":
        return "Beats Studio Buds+"
    default:
        return "Headphones"
    }
}
