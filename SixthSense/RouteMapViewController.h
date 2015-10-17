//
//  RouteMapViewController.h
//  SixthSense
//
//  Created by Samuel Parkinson on 17/10/2015.
//  Copyright © 2015 mettle-studio. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MapKit;

@interface RouteMapViewController : UIViewController

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (strong, nonatomic) MKPlacemark *mStartPlacemark;
@property (strong, nonatomic) MKPlacemark *mEndPlacemark;
@property (strong, nonatomic) MKRoute *_currentRoute;

@end
