//
//  ViewController.m
//  SimplePositioning
//
//  Created by André Hansson on 21/11/13.
//  Copyright (c) 2013 PingPal AB. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "Friend.h"
#import "MapViewController.h"

@interface ViewController ()
{
    NSMutableArray *tableViewData;
    
    NSMutableDictionary *fbNames;
    
    NSManagedObjectContext *context;
}

@property (weak, nonatomic) IBOutlet FBLoginView *loginView;

@property (weak, nonatomic) IBOutlet UIButton *updateButton;

@property (weak, nonatomic) IBOutlet UITableView *myTableView;

- (IBAction)updateButtonClicked:(id)sender;

@end

@implementation ViewController

@synthesize loginView, updateButton, myTableView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Get the managedObjectContext so we can interact with core data.
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    context = [appDelegate managedObjectContext];
    
    //Set the loginViews read permissions. Friend list is included in basic_info.
    [loginView setReadPermissions:@[@"basic_info"]];
    
	// Create a fetchRequest to get the users friends from core data
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friend"
                                              inManagedObjectContext:context];
    [fetchRequest setEntity:entity];
    
    // Sort them by name
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    
    NSError *error = nil;
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    if (fetchedObjects == nil){
        // Handle the error
        NSLog(@"ERROR: %@", error);
    }
    
    // Add the friends to the tableViewData array and reload the tableView to make the show
    tableViewData = [fetchedObjects mutableCopy];
    [myTableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - FBLoginViewDelegate

- (void)loginViewShowingLoggedInUser:(FBLoginView *)loginView {
     NSLog(@"loginViewShowingLoggedInUser");
    // Show the update button when the user is logged in
    [updateButton setHidden:NO];
}

- (void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView {
     NSLog(@"loginViewShowingLoggedOutUser");
    // Hide the update button when the user is logged out
    [updateButton setHidden:YES];
}

- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView
                            user:(id<FBGraphUser>)user {
    
    NSLog(@"loginViewFetchedUserInfo");
    
    // Save the users name so it can be sent with the messages to be shown in push notifications.
    [[NSUserDefaults standardUserDefaults]setObject:user.name forKey:@"myName"];
    
    // Check if I'm already registered with facebook.
    BOOL isRegisteredWithFB = [[NSUserDefaults standardUserDefaults]boolForKey:@"FB"];
    if (isRegisteredWithFB == NO)
    {
        // Send the users facebook id to the server to get them an UID
        [Outbox putTo:PP_VALUE_PROTOCOL_REST message:@{PP_KEY_ACTION:PP_VALUE_FB_ADD, @"fbid":user.id} inbox:self andSelector:@selector(FBRegisterInbox:)];
    }
}

-(void)FBRegisterInbox:(NSDictionary *)dict
{
    NSLog(@"FBRegisterInbox: %@", dict);
    
    // Check to see if it was successful.
    if ([dict[@"result"] isEqualToString:@"success"]) {
        
        NSString *UID = dict[@"response"];
        [[NSUserDefaults standardUserDefaults] setObject:UID forKey:@"UID"];
        
        // Set the UID so the connection to the server can be established.
        [Outbox setUID:UID];
        
        // Save that we registered with facebook
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FB"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    }else if ([dict[@"result"] isEqualToString:@"failure"]){
        NSLog(@"Facebook registration failed. %@", dict[@"response"]);
        
        // If it failed, show an alertView to tell the user to try again.
        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Facebook registration failed" message:@"Please try again" delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alertView show];
    }
}

// Facebook error handling
- (void)loginView:(FBLoginView *)loginView
      handleError:(NSError *)error {
    NSString *alertMessage, *alertTitle;
    if (error.fberrorShouldNotifyUser) {
        // If the SDK has a message for the user, surface it. This conveniently
        // handles cases like password change or iOS6 app slider state.
        alertTitle = @"Facebook Error";
        alertMessage = error.fberrorUserMessage;
    } else if (error.fberrorCategory == FBErrorCategoryAuthenticationReopenSession) {
        // It is important to handle session closures since they can happen
        // outside of the app. You can inspect the error for more context
        // but this sample generically notifies the user.
        alertTitle = @"Session Error";
        alertMessage = @"Your current Facebook session is no longer valid. Please log in again.";
    } else if (error.fberrorCategory == FBErrorCategoryUserCancelled) {
        // The user has cancelled a login. You can inspect the error
        // for more context. For this sample, we will simply ignore it.
        NSLog(@"user cancelled login");
    } else {
        // For simplicity, this sample treats other errors blindly.
        alertTitle  = @"Unknown Error";
        alertMessage = @"Error. Please try again later.";
        NSLog(@"Unexpected error:%@", error);
    }
    
    if (alertMessage) {
        [[[UIAlertView alloc] initWithTitle:alertTitle
                                    message:alertMessage
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}


#pragma mark - update button action

- (IBAction)updateButtonClicked:(id)sender
{
    // FBIDs is what we will send to the server to get matched.
    NSMutableArray *FBIDs = [[NSMutableArray alloc]init];
    
    // fbNames will be used to match the name and facebook ID later.
    fbNames = [[NSMutableDictionary alloc]init];
    
    // This is the facebook request to get all of the users friends.
    FBRequest* friendsRequest = [FBRequest requestForMyFriends];
    [friendsRequest startWithCompletionHandler: ^(FBRequestConnection *connection,
                                                  NSDictionary* result,
                                                  NSError *error) {
        NSArray* friends = [result objectForKey:@"data"];
        NSLog(@"Found: %lu friends", (unsigned long)friends.count);
        for (NSDictionary<FBGraphUser>* friend in friends) {
            
            [fbNames setObject:friend.name forKey:friend.id];
            [FBIDs addObject:friend.id];
        }
        
        // Send the array of friends facebook IDs to the server in order to see who of your friends had the app.
        [Outbox putTo:PP_VALUE_PROTOCOL_REST message:@{PP_KEY_ACTION: PP_VALUE_FB_MATCH, @"fbids":FBIDs} inbox:self andSelector:@selector(FBMatchInbox:)];
        
    }];
}

-(void)FBMatchInbox:(NSDictionary*)dict
{
    // Check to see if it succeeded.
    if ([dict[@"result"] isEqualToString:@"success"]) {
        
        // Make sure it's not empty
        if ([dict[@"response"] count] != 0) {
            
            // allKeys will be all the facebook id's of your friends that have the app.
            NSArray *allKeys = [dict[@"response"] allKeys];
            
            //Fetch friends
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            NSEntityDescription *entity = [NSEntityDescription entityForName:@"Friend"
                                                      inManagedObjectContext:context];
            [fetchRequest setEntity:entity];
            
            NSError *error = nil;
            NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
            if (fetchedObjects == nil){
                // Handle the error
                NSLog(@"ERROR: %@", error);
            }
            
            // Put all the friends uids in an array
            NSMutableArray *arr = [[NSMutableArray alloc]init];
            
            for (Friend *f in fetchedObjects)
            {
                [arr addObject:f.fbid];
            }
            
            
            for (NSString *key in allKeys)
            {
                // Check if the friend don't exist.
                if (![arr containsObject:key])
                {
                    // Create new friend object
                    Friend *newFriend = (Friend *) [NSEntityDescription insertNewObjectForEntityForName:@"Friend" inManagedObjectContext:context];
                    newFriend.name = [fbNames valueForKey:key];
                    newFriend.uid = [dict[@"response"] valueForKey:key];
                    newFriend.fbid = key;
                    
                    // Save the newly created friend
                    NSError *error = nil;
                    if (![context save:&error]) {
                        NSLog(@"Error! %@", error);
                    }
                    
                    // Add it to tableViewData, witch we use to fill our tableView
                    [tableViewData addObject:newFriend];
                    
                    // Reload the tableView
                    [myTableView reloadData];
                    
                }else{
                    NSLog(@"Friend already exist.");
                }
            }
            
        }else{
            // No new friends to add.
            NSLog(@"dict is empty");
        }
        
    }else if ([dict[@"result"] isEqualToString:@"failure"]){
        NSLog(@"Facebook match failed. %@", dict[@"response"]);
    }
}


#pragma mark - UITableView methods

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return tableViewData.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"myCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    Friend *friend = [tableViewData objectAtIndex:indexPath.row];
    
    cell.textLabel.text = friend.name;
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Check to see which friend we clicked and set their name as the title on the alertView.
    Friend *friend = [tableViewData objectAtIndex:indexPath.row];
    
    // The alertView will show three options Request position, request tracking and cancel.
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:friend.name message:nil delegate:self cancelButtonTitle:@"cancel" otherButtonTitles:@"Request position",@"Request tracking", nil];
    [alert show];
}


#pragma mark - AlertView

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:{
            NSLog(@"Cancel");
        }
            break;
            
        case 1:{
            NSLog(@"Request position");
            
            // Check to see which friend we selected
            NSIndexPath *selectedIndexPath = [myTableView indexPathForSelectedRow];
            Friend *friend = [tableViewData objectAtIndex:selectedIndexPath.row];
            
            // We instantiates the MapViewController from the storyboard and then set the current friend
            MapViewController *mapVC = [self.storyboard instantiateViewControllerWithIdentifier:@"MapView"];
            [mapVC setCurrentFriend:friend];
            
            // Puch the mapVC
            [self.navigationController pushViewController:mapVC animated:YES];
            
            // Send position request with an accuracy of 65 meters and an timeout of 30 seconds.
            // When we get a position it will fire the selector getDevicePosInbox: in mapVC.
            [LocationManager getDevicePosition:friend.uid withAccuracy:65 andTimeout:30 thenPerformSelector:@selector(getDevicePosInbox:) onObject:mapVC];
        }
            break;
            
        case 2:{
            NSLog(@"Request tracking");
            
            // Check to see which friend we selected
            NSIndexPath *selectedIndexPath = [myTableView indexPathForSelectedRow];
            Friend *friend = [tableViewData objectAtIndex:selectedIndexPath.row];
            
            // We instantiates the MapViewController from the storyboard and then set the current friend
            MapViewController *mapVC = [self.storyboard instantiateViewControllerWithIdentifier:@"MapView"];
            [mapVC setCurrentFriend:friend];
            
            // Push the mapVC
            [self.navigationController pushViewController:mapVC animated:YES];
            
            // Track without duration. It will continue to track until I leave the mapView.
            // When we get a position it will fire the selector trackDevicePosInbox: in mapVC. It will fire once for every new position.
            [LocationManager trackDevicePosition:friend.uid thenPerformSelector:@selector(trackDevicePosInbox:) onObject:mapVC];
            
            // Track with duration. Set a duration in seconds. When the time runs out no new locations will be tracked.
            //[LocationManager trackDevicePosition:friend.uid withDuration:10 thenPerformSelector:@selector(trackDevicePosInbox:) onObject:mapVC];
        }
            break;
            
        default:{
            
        }
            break;
    }
}

@end