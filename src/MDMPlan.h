/*
 Copyright 2016-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>

/**
 A class conforming to MDMPlan is expected to describe a plan of motion for a target.

 Plans are translated into performers by an instance of MDMScheduler.
 */
NS_SWIFT_NAME(Plan)
@protocol MDMPlan <NSObject, NSCopying>

#pragma mark Defining the performer class

/**
 Asks the receiver to return a class conforming to MDMPerformer.

 The returned class will be instantiated by an MDMScheduler. The instantiated performer is expected to
 execute the plan.
 */
- (nonnull Class)performerClass;

@end

/**
 Instances of `MDMNamedPlan` can be added or removed as named plans to or from targets.
 */
NS_SWIFT_NAME(NamedPlan)
@protocol MDMNamedPlan <MDMPlan>

@end
