//
//  ViewController.h
//  SixthSense
//
//  Created by Samuel Parkinson on 16/10/2015.
//  Copyright © 2015 mettle-studio. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MapKit;

@interface MapViewController : UIViewController

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) CLLocationManager *locationManager;

@end

