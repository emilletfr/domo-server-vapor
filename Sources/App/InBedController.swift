//
//  inBedController.swift
//  VaporApp
//
//  Created by Eric on 28/11/2016.
//
//

import Foundation
import Dispatch
import Vapor
import HTTP

class InBedController
{
    var isInBed = false
    var repeatTimerQueue : DispatchQueue?
    
    init() {
        self.repeatTimerQueue = DispatchQueue(label: "InBedController.Timer")
        self.repeatTimerQueue?.async { // DispatchSourceTimer : 100% cpu
            while (true)
            {
                self.retrieveValue()
                sleep(10)
            }
        }
    }
    
    func retrieveValue()
    {
        let urlString = "http://10.0.1.14/status"
        let response = try? drop.client.get(urlString)
        guard let inBed = response?.json?["inBed"]?.int else {return}
        self.isInBed = inBed == 1
    }

}