//
//  ViewController.m
//  SixthSense
//
//  Created by Samuel Parkinson on 16/10/2015.
//  Copyright © 2015 mettle-studio. All rights reserved.
//

#import "MapViewController.h"
#import "RouteMapViewController.h"
#import "HFCommander.h"

@interface MapViewController () <MKMapViewDelegate, CLLocationManagerDelegate> {
    MKPolyline *_routeOverlay;
    MKRoute *_currentRoute;
    __weak IBOutlet UIButton *_startButton;
    __weak IBOutlet UIButton *_endButton;
    __weak IBOutlet UILabel *_addressLabel;
    CLLocationCoordinate2D _hackathon;
    MKPlacemark *mStartPlacemark;
    MKPlacemark *mEndPlacemark;
    BOOL editingStart;
    BOOL init;
    UIColor *darkBlue;
}
@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    darkBlue = [UIColor colorWithRed:0.04313 green:0.2392 blue:0.3725 alpha:1.0];
    editingStart = YES;
    
    self.mapView.delegate = self;
    
    _hackathon = CLLocationCoordinate2DMake(51.52257020, -0.08550030);
    mStartPlacemark = [[MKPlacemark alloc] initWithCoordinate:_hackathon addressDictionary:nil];
    mEndPlacemark = [[MKPlacemark alloc] initWithCoordinate:_hackathon addressDictionary:nil];
    
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(_hackathon, 500, 500);
    MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:viewRegion];
    [self.mapView setRegion:adjustedRegion animated:YES];
    
    [self.mapView setCenterCoordinate:_hackathon animated:YES];
    
    [self.mapView addAnnotation:mEndPlacemark];
    [self.mapView addAnnotation:mStartPlacemark];
    
    [HFCommander sharedCommander];
    
    [self setTitle:@"Nudge"];
}

-(void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if (editingStart) {
        [self.mapView removeAnnotation:mStartPlacemark];
        mStartPlacemark = [[MKPlacemark alloc] initWithCoordinate:mapView.centerCoordinate addressDictionary:nil];
        [self.mapView addAnnotation:mStartPlacemark];
        [self updateLocationAndRouteWithPlacemark:mStartPlacemark];
    }
    else {
        [self.mapView removeAnnotation:mEndPlacemark];
        mEndPlacemark = [[MKPlacemark alloc] initWithCoordinate:mapView.centerCoordinate addressDictionary:nil];
        [self.mapView addAnnotation:mEndPlacemark];
        [self updateLocationAndRouteWithPlacemark:mEndPlacemark];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)plotRouteOnMap:(MKRoute *)route
{
    if(_routeOverlay) {
        [self.mapView removeOverlay:_routeOverlay];
    }
    
    // Update the ivar
    _routeOverlay = route.polyline;
    
    // Add it to the map
    [self.mapView addOverlay:_routeOverlay];
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];
    renderer.strokeColor = darkBlue;
    renderer.lineWidth = 4.0;
    return  renderer;
}

- (IBAction)startPressed:(id)sender {
    editingStart = YES;
    _startButton.backgroundColor = darkBlue;
    _startButton.tintColor = [UIColor whiteColor];
    _endButton.backgroundColor = [UIColor whiteColor];
    _endButton.tintColor = darkBlue;
    [self.mapView setCenterCoordinate:mStartPlacemark.coordinate animated:YES];
}

- (IBAction)endPressed:(id)sender {
    editingStart = NO;
    _endButton.backgroundColor = darkBlue;
    _endButton.tintColor = [UIColor whiteColor];
    _startButton.backgroundColor = [UIColor whiteColor];
    _startButton.tintColor = darkBlue;
    [self.mapView setCenterCoordinate:mEndPlacemark.coordinate animated:YES];
    [self updateLocationAndRouteWithPlacemark:mEndPlacemark];
}

- (void) updateLocationAndRouteWithPlacemark:(MKPlacemark *)placemark {
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:placemark.coordinate
                                                         altitude:0
                                               horizontalAccuracy:1
                                                 verticalAccuracy:1
                                                           course:0
                                                            speed:0
                                                        timestamp:[NSDate date]];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if(error){
            NSLog(@"%@", [error localizedDescription]);
        }
        
        CLPlacemark *placemark = [placemarks lastObject];
        
        NSString *number = @"";
        if (placemark.subThoroughfare)
            number = [NSString stringWithFormat:@"%@ ",
                      placemark.subThoroughfare];
        
        NSString *address = [NSString stringWithFormat:@"%@%@ %@",
                             number, placemark.thoroughfare,
                             placemark.postalCode];
        
        NSLog(@"%@", address);
        [_addressLabel setText:address];
    }];
    [self showDirections];
}

- (void)showDirections {
    // Make a directions request
    MKDirectionsRequest *directionsRequest = [MKDirectionsRequest new];
    directionsRequest.transportType = MKDirectionsTransportTypeWalking;
    
    // Start at our current location
    MKPlacemark *sourcePlacemark = [[MKPlacemark alloc] initWithCoordinate:mStartPlacemark.coordinate addressDictionary:nil];
    MKMapItem *source = [[MKMapItem alloc] initWithPlacemark:sourcePlacemark];
    [directionsRequest setSource:source];
    
    // Make the destination
    MKPlacemark *destinationPlacemark = [[MKPlacemark alloc] initWithCoordinate:mEndPlacemark.coordinate addressDictionary:nil];
    MKMapItem *destination = [[MKMapItem alloc] initWithPlacemark:destinationPlacemark];
    [directionsRequest setDestination:destination];
    
    MKDirections *directions = [[MKDirections alloc] initWithRequest:directionsRequest];
    [directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse *response, NSError *error) {
        // Now handle the result
        if (error) {
            NSLog(@"There was an error getting your directions");
            return;
        }
        
        // So there wasn't an error - let's plot those routes
        _currentRoute = [response.routes firstObject];
        
        [self plotRouteOnMap:_currentRoute];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showRoute"]) {
        RouteMapViewController *routeViewController = segue.destinationViewController;
        routeViewController.mStartPlacemark = mStartPlacemark;
        routeViewController.mEndPlacemark = mEndPlacemark;
        routeViewController._currentRoute = _currentRoute;
    }
}

@end
