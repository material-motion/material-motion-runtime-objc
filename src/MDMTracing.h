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

@protocol MDMPerforming;
@protocol MDMPlan;

/**
 A tracer object may implement a variety of hooks for the purposes of observing changes to the
 internal workings of a scheduler.
 */
NS_SWIFT_NAME(Tracing)
@protocol MDMTracing <NSObject>
@optional

/** Invoked after a plan has been added to the scheduler. */
- (void)didAddPlan:(nonnull id<MDMPlan>)plan to:(nonnull id)target
    NS_SWIFT_NAME(didAddPlan(_:to:));

/** Invoked after a performer has been created by the scheduler. */
- (void)didCreatePerformer:(nonnull id<MDMPerforming>)performer for:(nonnull id)target
    NS_SWIFT_NAME(didCreatePerformer(_:for:));

@end
