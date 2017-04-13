//
//  FirstViewController.m
//  MyMessenger
//
//  Created by SendBird Developers on 12/4/15.
//  Copyright © 2015 SENDBIRD.COM. All rights reserved.
//

#import "OpenChatChannelListViewController.h"

@interface OpenChatChannelListViewController ()<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate> {
    NSMutableArray *channelArray;
    BOOL isLoadingChannel;
    SendBirdChannelListQuery *channelListQuery;
}

@end

@implementation OpenChatChannelListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    isLoadingChannel = NO;
    
    [self.openChatChannelListTableView setContentInset:UIEdgeInsetsMake(108, 0, 48, 0)];
    [self.openChatChannelListTableView setDelegate:self];
    [self.openChatChannelListTableView setDataSource:self];
    
    [self.channelSearchBar setDelegate:self];
    
    channelArray = [[NSMutableArray alloc] init];
    
    [self.openChatChannelListLoadingIndicator setHidden:YES];

   [SendBird loginWithUserId:[SendBird deviceUniqueID] andUserName:[MyUtils getUserName] andUserImageUrl:[MyUtils getUserProfileImage] andAccessToken:@""];
   channelListQuery = [SendBird queryChannelList];
   [channelListQuery nextWithResultBlock:^(NSMutableArray *queryResult) {
      for (SendBirdChannel *channel in queryResult) {
         [channelArray addObject:channel];
      }
      [self.openChatChannelListTableView reloadData];
   } endBlock:^(NSError *error) {
      
   }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[OpenChatChattingViewController class]]) {
        NSIndexPath *path = [self.openChatChannelListTableView indexPathForSelectedRow];
        OpenChatChattingViewController *vc = (OpenChatChattingViewController *)segue.destinationViewController;
        SendBirdChannel *channel = [channelArray objectAtIndex:[path row]];
        [vc setChannel:channel];
        
        [self.openChatChannelListTableView deselectRowAtIndexPath:path animated:NO];
    }
}

- (void)loadNextChannelList
{
   if (![channelListQuery hasNext]) {
      return;
   }
   
   if (isLoadingChannel) {
      return;
   }
   isLoadingChannel = YES;
   
   [channelListQuery nextWithResultBlock:^(NSMutableArray *queryResult) {
      for (SendBirdChannel *channel in queryResult) {
         [channelArray addObject:channel];
      }
      [self.openChatChannelListTableView reloadData];
      isLoadingChannel = NO;
   } endBlock:^(NSError *error) {
      
   }];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [channelArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 0) {
        OpenChatChannelListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenChatChannelListCell"];
        SendBirdChannel *channel = (SendBirdChannel *)[channelArray objectAtIndex:[indexPath row]];
        [cell setChannel:channel];
        
        if ([indexPath row] + 1 == [channelArray count]) {
            [self loadNextChannelList];
        }
        
        return cell;
    }
    else {
        return nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64;
}

#pragma mark - UISearchBarDelegate
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
   [channelArray removeAllObjects];
   [searchBar setText:@""];
   channelListQuery = [SendBird queryChannelList];
   [channelListQuery setQuery:@""];
   [channelListQuery nextWithResultBlock:^(NSMutableArray *queryResult) {
      for (SendBirdChannel *channel in queryResult) {
         [channelArray addObject:channel];
      }
      [self.openChatChannelListTableView reloadData];
   } endBlock:^(NSError *error) {
      
   }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
   [channelArray removeAllObjects];
   channelListQuery = [SendBird queryChannelList];
   [channelListQuery setQuery:[searchBar text]];
   [channelListQuery nextWithResultBlock:^(NSMutableArray *queryResult) {
      for (SendBirdChannel *channel in queryResult) {
         [channelArray addObject:channel];
      }
      [self.openChatChannelListTableView reloadData];
   } endBlock:^(NSError *error) {
      
   }];
}

@end
