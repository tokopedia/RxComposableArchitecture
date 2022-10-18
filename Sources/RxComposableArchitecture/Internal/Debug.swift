//
//  Debug.swift
//
//
//  Created by jefferson.setiawan on 02/08/22.
//

extension String {
    func indent(by indent: Int) -> String {
        let indentation = String(repeating: " ", count: indent)
        return indentation + self.replacingOccurrences(of: "\n", with: "\n\(indentation)")
    }
}
