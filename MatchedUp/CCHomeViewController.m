//
//  CCHomeViewController.m
//  MatchedUp
//
//  Created by Eliot Arntz on 12/7/13.
//  Copyright (c) 2013 Code Coalition. All rights reserved.
//

#import "CCHomeViewController.h"
#import "CCTestUser.h"
#import "CCProfileViewController.h"

@interface CCHomeViewController ()

@property (strong, nonatomic) IBOutlet UIBarButtonItem *chatBarButtonItem;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsBarButtonItem;
@property (strong, nonatomic) IBOutlet UIImageView *photoImageView;
@property (strong, nonatomic) IBOutlet UILabel *firstNameLabel;
@property (strong, nonatomic) IBOutlet UILabel *ageLabel;
@property (strong, nonatomic) IBOutlet UILabel *tagLineLabel;
@property (strong, nonatomic) IBOutlet UIButton *likeButton;
@property (strong, nonatomic) IBOutlet UIButton *infoButton;
@property (strong, nonatomic) IBOutlet UIButton *dislikeButton;

@property (strong, nonatomic) NSArray *photos;
@property (strong, nonatomic) PFObject *photo;
@property (strong, nonatomic) NSMutableArray *activities;

@property (nonatomic) int currentPhotoIndex;
@property (nonatomic) BOOL isLikedByCurrentUser;
@property (nonatomic) BOOL isDislikedByCurrentUser;


@end

@implementation CCHomeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    /* Uncomment to create a test user */
    //[CCTestUser saveTestUserToParse];
    
    /* Set our buttons to be disabled until we finish downloading the file from Parse. */
    self.likeButton.enabled = NO;
    self.dislikeButton.enabled = NO;
    self.infoButton.enabled = NO;
    
    /* Start off with the first object we get back from our array of photo's. */
    self.currentPhotoIndex = 0;
    
    /* Create a PFQuery object to query for all Photo objects. Constraint the query.  */
    PFQuery *query = [PFQuery queryWithClassName:kCCPhotoClassKey];
    /* Constrain the query to exclude the current user */
    [query whereKey:kCCPhotoUserKey notEqualTo:[PFUser currentUser]];
    /* Download the complete User object for the query */
    [query includeKey:kCCPhotoUserKey];
    /* Run the query */
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error){
            /* Set the returned objects array equal to the photos property */
            self.photos = objects;
            /* Call the helper method to update start the photo download */
            [self queryForCurrentPhotoIndex];
        }
        else {
            NSLog(@"%@", error);
        }
    }];
    
    //do additional
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"homeToProfileSegue"])
    {
        CCProfileViewController *profileVC = segue.destinationViewController;
        profileVC.photo = self.photo;
    }
}

#pragma mark - IBActions

- (IBAction)likeButtonPressed:(UIButton *)sender
{
    [self checkLike];
}

- (IBAction)dislikeButtonPressed:(UIButton *)sender
{
    [self checkDislike];
}

- (IBAction)infoButtonPressed:(UIButton *)sender
{
    [self performSegueWithIdentifier:@"homeToProfileSegue" sender:nil];
}

- (IBAction)settingsBarButtonItemPressed:(UIBarButtonItem *)sender
{
    
}


- (IBAction)chatBarButtonItemPressed:(UIBarButtonItem *)sender
{
    
}

#pragma mark - Helper Methods

- (void)queryForCurrentPhotoIndex
{
    if ([self.photos count] > 0) {
        /* Set the current photo from the photos array */
        self.photo = self.photos[self.currentPhotoIndex];
        /* Access the PFFile stored for the photo */
        PFFile *file = self.photo[kCCPhotoPictureKey];
        /* Get the data for the image file on a background thread */
        [file getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
            if (!error){
                /* Create a UIImage with the data returned from the background thread. Update the photoImage view with the UIImage.*/
                UIImage *image = [UIImage imageWithData:data];
                self.photoImageView.image = image;
                [self updateView];
            }
            else NSLog(@"%@", error);
        }];
        
        /* Create a PFQuery for Activities. Constrain the query to only return likes for the current photo and for the current user. */
        PFQuery *queryForLike = [PFQuery queryWithClassName:kCCActivityClassKey];
        [queryForLike whereKey:kCCActivityTypeKey equalTo:kCCActivityTypeLikeKey];
        [queryForLike whereKey:kCCActivityPhotoKey equalTo:self.photo];
        [queryForLike whereKey:kCCActivityFromUserKey equalTo:[PFUser currentUser]];
        
        /* Create a PFQuery for Activities. Constrain the query to only return dislikes for the current photo and for the current user. */
        PFQuery *queryForDislike = [PFQuery queryWithClassName:kCCActivityClassKey];
        [queryForDislike whereKey:kCCActivityTypeKey equalTo:kCCActivityTypeDislikeKey];
        [queryForDislike whereKey:kCCActivityPhotoKey equalTo:self.photo];
        [queryForDislike whereKey:kCCActivityFromUserKey equalTo:[PFUser currentUser]];
        
        /* Join the likes and dislikes queries together */
        PFQuery *likeAndDislikeQuery = [PFQuery orQueryWithSubqueries:@[queryForLike, queryForDislike]];
        [likeAndDislikeQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            if (!error){
                /* Store the returned activities in the property self.activities */
                self.activities = [objects mutableCopy];
                
                /* If there are no activities the user has not liked or disliked the photo yet */
                if ([self.activities count] == 0) {
                    self.isLikedByCurrentUser = NO;
                    self.isDislikedByCurrentUser = NO;
                } else {
                    PFObject *activity = self.activities[0];
                    
                    /* Determine if the user has liked or disliked the photo */
                    if ([activity[kCCActivityTypeKey] isEqualToString:kCCActivityTypeLikeKey]){
                        self.isLikedByCurrentUser = YES;
                        self.isDislikedByCurrentUser = NO;
                    }
                    else if ([activity[kCCActivityTypeKey] isEqualToString:kCCActivityTypeDislikeKey]){
                        self.isLikedByCurrentUser = NO;
                        self.isDislikedByCurrentUser = YES;
                    }
                    else {
                        //Some other type of activity
                    }
                }
                /* After the query is complete enable all buttons. */
                self.likeButton.enabled = YES;
                self.dislikeButton.enabled = YES;
                self.infoButton.enabled = YES;
            }
        }];
    }
}

/* Update the UI with the PFObject, self.photo */
- (void)updateView
{
    self.firstNameLabel.text = self.photo[kCCPhotoUserKey][kCCUserProfileKey][kCCUserProfileFirstNameKey];
    self.ageLabel.text = [NSString stringWithFormat:@"%@",self.photo[kCCPhotoUserKey][kCCUserProfileKey][kCCUserProfileAgeKey]];
    self.tagLineLabel.text = self.photo[kCCPhotoUserKey][kCCUserTagLineKey];
}

/* Load the next photo in the photo's array */
- (void)setupNextPhoto
{
    if (self.currentPhotoIndex + 1 <self.photos.count)
    {
        self.currentPhotoIndex ++;
        [self queryForCurrentPhotoIndex];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No More Users to View" message:@"Check Back Later for more People!" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
        [alert show];
    }
}

/* Create a PFObject and set its' class name to Activity. Setup key-value pairs for the PFObject for the type of actvitiy, the user doing the liking, the user being liked and the photo selected */
- (void)saveLike
{
    PFObject *likeActivity = [PFObject objectWithClassName:kCCActivityClassKey];
    [likeActivity setObject:kCCActivityTypeLikeKey forKey:kCCActivityTypeKey];
    [likeActivity setObject:[PFUser currentUser] forKey:kCCActivityFromUserKey];
    [likeActivity setObject:[self.photo objectForKey:kCCPhotoUserKey] forKey:kCCActivityToUserKey];
    [likeActivity setObject:self.photo forKey:kCCActivityPhotoKey];
    [likeActivity saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        self.isLikedByCurrentUser = YES;
        self.isDislikedByCurrentUser = NO;
        [self.activities addObject:likeActivity];
        [self setupNextPhoto];
    }];
}

/* Create a PFObject and set its' class name to Activity. Setup key-value pairs for the PFObject for the type of actvitiy, the user doing the liking, the user being liked and the photo selected */
- (void)saveDislike
{
    PFObject *dislikeActivity = [PFObject objectWithClassName:kCCActivityClassKey];
    [dislikeActivity setObject:kCCActivityTypeDislikeKey forKey:kCCActivityTypeKey];
    [dislikeActivity setObject:[PFUser currentUser] forKey:kCCActivityFromUserKey];
    [dislikeActivity setObject:[self.photo objectForKey:kCCPhotoUserKey] forKey:kCCActivityToUserKey];
    [dislikeActivity setObject:self.photo forKey:kCCActivityPhotoKey];
    [dislikeActivity saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        self.isLikedByCurrentUser = NO;
        self.isDislikedByCurrentUser = YES;
        [self.activities addObject:dislikeActivity];
        [self setupNextPhoto];
    }];
}

/* If the user has already liked the photo go to the next photo. If the user has disliked the photo remove the dislike before liking. Otherwise like the photo */
- (void)checkLike
{
    if (self.isLikedByCurrentUser) {
        [self setupNextPhoto];
        return;
    }
    else if (self.isDislikedByCurrentUser) {
        for (PFObject *activity in self.activities){
            [activity deleteInBackground];
        }
        [self.activities removeLastObject];
        [self saveLike];
    }
    else {
        [self saveLike];
    }
}

/* If the user has already disliked the photo go to the next photo. If the user has liked the photo remove the dislike before liking. Otherwise like the photo */
- (void)checkDislike
{
    if (self.isDislikedByCurrentUser){
        [self setupNextPhoto];
        return;
    }
    else if (self.isLikedByCurrentUser){
        for (PFObject *activity in self.activities){
            [activity deleteInBackground];
        }
        [self.activities removeLastObject];
        [self saveDislike];
    }
    else {
        [self saveDislike];
    }
}

@end
