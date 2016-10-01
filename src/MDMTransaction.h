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

@protocol MDMPlan;
@protocol MDMNamedPlan;

// clang-format off
/**
 The MDMTransaction class acts as a register of operations that may be committed to an instance of
 MDMScheduler.
 */
__deprecated_msg("Add plans directly to a scheduler instead.")
NS_SWIFT_NAME(Transaction)
@interface MDMTransaction : NSObject

#pragma mark Adding plans to a transaction

/**
 Associates a plan with a given target.

 @param plan The plan to add to this transaction.
 @param target The target on which the plan can operate.
*/
- (void)addPlan:(nonnull id<MDMPlan>)plan
       toTarget:(nonnull id)target
  NS_SWIFT_NAME(add(plan:to:))
  __deprecated_msg("Add plans directly to a scheduler instead.");

/**
 Associates a named plan with a given target.
 
 @param plan The plan to add to this transaction.
 @param name String identifier for the plan.
 @param target The target on which the plan can operate.
 */
- (void)addPlan:(nonnull id<MDMNamedPlan>)plan
          named:(nonnull NSString *)name
       toTarget:(nonnull id)target
  NS_SWIFT_NAME(addPlan(_:named:to:))
  __deprecated_msg("Add plans directly to a scheduler instead.");

/**
 Removes any plan associated with the given name on the given target.
 
 @param name String identifier for the plan.
 @param target The target on which the plan can operate.
 */
- (void)removePlanNamed:(nonnull NSString *)name
             fromTarget:(nonnull id)target
  NS_SWIFT_NAME(removePlan(named:from:))
  __deprecated_msg("Remove plans directly from a scheduler instead.");

@end
    // clang-format on
