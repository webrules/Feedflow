import Foundation

class OPMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var feeds: [(title: String, url: String)] = []
    
    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }
    
    func parse() -> [(title: String, url: String)] {
        parser.parse()
        return feeds
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "outline" {
            // Check for xmlUrl
            if let url = attributeDict["xmlUrl"] {
                // Try to find the best title: text > title > url
                let title = attributeDict["text"] ?? attributeDict["title"] ?? url
                feeds.append((title, url))
            }
        }
    }
}
