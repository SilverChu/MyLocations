//
//  Location+CoreDataClass.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/6/23.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import Foundation
import CoreData
import MapKit

@objc(Location)
class Location: NSManagedObject, MKAnnotation {

    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
    
    var title: String? {
        if locationDescription.isEmpty {
            return "(No Description)"
        } else {
            return locationDescription
        }
    }
    
    var subtitle: String? {
        return category
    }
    
}
