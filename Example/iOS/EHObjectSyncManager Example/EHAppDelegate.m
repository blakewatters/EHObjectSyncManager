//
//  EHAppDelegate.m
//  EHObjectSyncManager Example
//
//  Created by Eric Horacek on 4/1/13.
//  Copyright (c) 2013 Eric Horacek. All rights reserved.
//

#import "EHAppDelegate.h"
#import "EHTasksViewController.h"
#import "EHObjectSyncManager.h"
#import "EHTask.h"
#import "EHReminder.h"
#import "EHStyleManager.h"

@interface EHAppDelegate ()

- (void)setupRestKitWithBaseURL:(NSURL *)baseURL;
- (void)setupPonyDebugger;

@end

@implementation EHAppDelegate

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setupRestKitWithBaseURL:[NSURL URLWithString:@"http://ehobjectsyncmanager.herokuapp.com"]];
//    [self setupRestKitWithBaseURL:[NSURL URLWithString:@"http://ehobjectsyncmanager.192.168.100.8.xip.io"]];
//    [self setupRestKitWithBaseURL:[NSURL URLWithString:@"http://ehobjectsyncmanager.dev"]];
    
    [self setupPonyDebugger];
    
    [EHStyleManager sharedManager];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    EHTasksViewController *tasksController = [[EHTasksViewController alloc] init];
    tasksController.managedObjectContext = [[EHObjectSyncManager sharedManager] managedObjectContext];
//    tasksController.managedObjectContext = [[RKManagedObjectStore defaultStore] mainQueueManagedObjectContext];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:tasksController];
    self.window.rootViewController = navigationController;
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

#pragma mark - EHAppDelegate

- (void)setupRestKitWithBaseURL:(NSURL *)baseURL
{
    EHObjectSyncManager *objectManager = [EHObjectSyncManager managerWithBaseURL:baseURL];
    
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;

    // Initialize managed object store
    NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    RKManagedObjectStore *managedObjectStore = [[RKManagedObjectStore alloc] initWithManagedObjectModel:managedObjectModel];
    objectManager.managedObjectStore = managedObjectStore;
    
    RKEntityMapping *taskResponseMapping = [RKEntityMapping mappingForEntityForName:@"Task" inManagedObjectStore:managedObjectStore];
    taskResponseMapping.identificationAttributes = @[ @"remoteID" ];
    [taskResponseMapping addAttributeMappingsFromDictionary:@{ @"id" : @"remoteID", @"completed_at" : @"completedAt", @"due_at" : @"dueAt"}];
    [taskResponseMapping addAttributeMappingsFromArray:@[ @"name" ]];
    
    RKEntityMapping *reminderResponseMapping = [RKEntityMapping mappingForEntityForName:@"Reminder" inManagedObjectStore:managedObjectStore];
    reminderResponseMapping.identificationAttributes = @[ @"remoteID" ];
    [reminderResponseMapping addAttributeMappingsFromDictionary:@{ @"id" : @"remoteID", @"task_id" : @"taskID", @"remind_at" : @"remindAt" }];
    
    // Task <->> Reminder
    [taskResponseMapping addPropertyMapping:[RKRelationshipMapping relationshipMappingFromKeyPath:@"reminders" toKeyPath:@"reminders" withMapping:reminderResponseMapping]];
    [reminderResponseMapping addConnectionForRelationship:@"task" connectedBy:@{@"taskID" : @"remoteID"}];
    
    RKResponseDescriptor *taskIndexResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:taskResponseMapping pathPattern:@"/tasks.json" keyPath:@"task" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    [objectManager addResponseDescriptor:taskIndexResponseDescriptor];
    
    RKResponseDescriptor *taskResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:taskResponseMapping pathPattern:@"/tasks/:remoteID\\.json" keyPath:@"task" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    [objectManager addResponseDescriptor:taskResponseDescriptor];
    
    RKResponseDescriptor *reminderIndexResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:reminderResponseMapping pathPattern:@"/reminders.json" keyPath:@"reminder" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    [objectManager addResponseDescriptor:reminderIndexResponseDescriptor];
    
    RKResponseDescriptor *reminderResponseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:reminderResponseMapping pathPattern:@"/reminders/:remoteID\\.json" keyPath:@"reminder" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
    [objectManager addResponseDescriptor:reminderResponseDescriptor];
    
    RKObjectMapping* taskRequestMapping = [RKObjectMapping requestMapping];
    [taskRequestMapping addAttributeMappingsFromArray:@[ @"name" ]];
    [taskRequestMapping addAttributeMappingsFromDictionary:@{ @"completedAt" : @"completed_at", @"dueAt" : @"due_at" }];
    taskRequestMapping.setDefaultValueForMissingAttributes = YES;
    
    RKObjectMapping* reminderRequestMapping = [RKObjectMapping requestMapping];
    [reminderRequestMapping addAttributeMappingsFromDictionary:@{ @"remindAt" : @"remind_at", @"task.remoteID" : @"task_id" }];
    reminderRequestMapping.setDefaultValueForMissingAttributes = YES;
    
    RKRequestDescriptor *taskRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:taskRequestMapping objectClass:EHTask.class rootKeyPath:@"task"];
    [objectManager addRequestDescriptor:taskRequestDescriptor];
    
    RKRequestDescriptor *reminderRequestDescriptor = [RKRequestDescriptor requestDescriptorWithMapping:reminderRequestMapping objectClass:EHReminder.class rootKeyPath:@"reminder"];
    [objectManager addRequestDescriptor:reminderRequestDescriptor];
    
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHTask.class pathPattern:@"/tasks/:remoteID\\.json" method:RKRequestMethodGET]];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHTask.class pathPattern:@"/tasks/:remoteID\\.json" method:RKRequestMethodPUT]];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHTask.class pathPattern:@"/tasks/:remoteID\\.json" method:RKRequestMethodDELETE]];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHTask.class pathPattern:@"/tasks.json" method:RKRequestMethodPOST]];
    
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHReminder.class pathPattern:@"/reminders/:remoteID\\.json" method:RKRequestMethodGET]];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHReminder.class pathPattern:@"/reminders/:remoteID\\.json" method:RKRequestMethodPUT]];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHReminder.class pathPattern:@"/reminders/:remoteID\\.json" method:RKRequestMethodDELETE]];
    [objectManager.router.routeSet addRoute:[RKRoute routeWithClass:EHReminder.class pathPattern:@"/reminders.json" method:RKRequestMethodPOST]];
    
    [objectManager addFetchRequestBlock:^NSFetchRequest *(NSURL *URL) {
        RKPathMatcher *pathMatcher = [RKPathMatcher pathMatcherWithPattern:@"/tasks.json"];
        if (![pathMatcher matchesPath:[URL relativePath] tokenizeQueryStrings:NO parsedArguments:nil]) return nil;
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Task"];
        return fetchRequest;
    }];
    
    [objectManager addFetchRequestBlock:^NSFetchRequest *(NSURL *URL) {
        RKPathMatcher *pathMatcher = [RKPathMatcher pathMatcherWithPattern:@"/tasks.json"];
        if (![pathMatcher matchesPath:[URL relativePath] tokenizeQueryStrings:NO parsedArguments:nil]) return nil;
        // A task index returns all reminders that have tasks, these must be included
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Reminder"];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(task != nil)"];
        return fetchRequest;
    }];
    
    [objectManager addFetchRequestBlock:^NSFetchRequest *(NSURL *URL) {
        RKPathMatcher *pathMatcher = [RKPathMatcher pathMatcherWithPattern:@"/reminders.json"];
        NSDictionary *argsDict = nil;
        if (![pathMatcher matchesPath:[URL relativePath] tokenizeQueryStrings:NO parsedArguments:&argsDict]) return nil;
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Reminder"];
        if (argsDict[@"task_id"]) {
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(task.remoteID == %@)", argsDict[@"task_id"]];
        }
        return fetchRequest;
    }];
    
    [objectManager addSyncDescriptor:[EHSyncDescriptor syncDescriptorWithMapping:taskResponseMapping syncRank:@1 existsRemotelyBlock:^BOOL(id task) {
        return ([task valueForKey:@"remoteID"] != nil);
    }]];
    
    [objectManager addSyncDescriptor:[EHSyncDescriptor syncDescriptorWithMapping:reminderResponseMapping syncRank:@2 existsRemotelyBlock:^BOOL(id reminder) {
        return ([reminder valueForKey:@"remoteID"] != nil);
    }]];
    
    [managedObjectStore createPersistentStoreCoordinator];
    NSString *storePath = [RKApplicationDataDirectory() stringByAppendingPathComponent:@"Store.sqlite"];
    NSError *error;
    NSPersistentStore *persistentStore = [managedObjectStore addSQLitePersistentStoreAtPath:storePath fromSeedDatabaseAtPath:nil withConfiguration:nil options:nil error:&error];
    NSAssert(persistentStore, @"Failed to add persistent store with error: %@", error);
    [managedObjectStore createManagedObjectContexts];
    
    [objectManager configureSyncManagerWithManagedObjectStore:managedObjectStore];
    
    managedObjectStore.managedObjectCache = [[RKFetchRequestManagedObjectCache alloc] init];
    
//    RKLogConfigureByName("RestKit/ObjectMapping", RKLogLevelTrace);
//    RKLogConfigureByName("RestKit/CoreData", RKLogLevelTrace);
//    RKLogConfigureByName("RestKit/Network", RKLogLevelTrace);
//    RKLogConfigureByName("RestKit", RKLogLevelTrace);
}

- (void)setupPonyDebugger
{
    PDDebugger *debugger = [PDDebugger defaultInstance];
    [debugger connectToURL:[NSURL URLWithString:@"ws://localhost:9000/device"]];
//    [debugger autoConnect];
    
    [debugger enableNetworkTrafficDebugging];
    [debugger forwardAllNetworkTraffic];
    
//    [debugger enableViewHierarchyDebugging];
    
    [debugger enableCoreDataDebugging];
    [debugger addManagedObjectContext:[[RKManagedObjectStore defaultStore] persistentStoreManagedObjectContext] withName:@"RKManagedObjectStore Persistent Store"];
    [debugger addManagedObjectContext:[[RKManagedObjectStore defaultStore] mainQueueManagedObjectContext] withName:@"RKManagedObjectStore Main Queue"];
    [debugger addManagedObjectContext:[[EHObjectSyncManager sharedManager] managedObjectContext] withName:@"EHObjectSyncManager Context"];
}

@end
