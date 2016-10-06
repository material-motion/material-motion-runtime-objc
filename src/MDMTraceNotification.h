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

// clang-format off

#pragma mark - Trace Notification Name

/**
 Enable support for treating trace notification names as Swift enums.

 Any trace notification name defined with the MDMTraceNotificationName type will be made available
 as TraceNotificationName.<name> in Swift code.
 */
__deprecated_msg("Use MDMTracing and MDMScheduler's addTracer: instead.")
typedef NSNotificationName MDMTraceNotificationName NS_EXTENSIBLE_STRING_ENUM
    NS_SWIFT_NAME(TraceNotificationName);

/**
 A key whose value is an object that contains information relevant to the corresponding
 notification.

 The value of this key depends on the notification.
 */
__deprecated_msg("Use MDMTracing and MDMScheduler's addTracer: instead.")
FOUNDATION_EXTERN NSString* const _Nonnull MDMTraceNotificationPayloadKey
    NS_SWIFT_NAME(TraceNotificationPayloadKey);

#pragma mark - Trace Notifications

#pragma mark Notification: Performers Created

/**
 Name of the notification that is fired when new performers are created as part of a transaction.

 Sent on completion of a MDMScheduler commitTransaction: invocation only if new performers were
 created.

 The notification's user info MDMTraceNotificationPayloadKey's value is an instance of
 MDMSchedulerPerformersCreatedTracePayload.
 */
__deprecated_msg("Use MDMTracing and MDMScheduler's addTracer: instead.")
FOUNDATION_EXPORT MDMTraceNotificationName _Nonnull MDMTraceNotificationNamePerformersCreated;

/** Data for the MDMTraceNotificationNamePerformersCreated notification. */
__deprecated_msg("Use MDMTracing and MDMScheduler's addTracer: instead.")
NS_SWIFT_NAME(SchedulerPerformersCreatedTracePayload)
@interface MDMSchedulerPerformersCreatedTracePayload : NSObject

/** The set of performers that were created by the transaction. */
@property(nonatomic, copy, nonnull, readonly) NSSet<MDMPerforming>* createdPerformers;

@end

#pragma mark Notification: Plans Committed

/**
 Name of the notification that is fired when new plans are committed to a scheduler.

 Sent on completion of a MDMScheduler commitTransaction: invocation only if plans were committed.

 The notification's user info MDMTraceNotificationPayloadKey's value is an instance of
 MDMSchedulerPlansCommittedTracePayload.
 */
__deprecated_msg("Use MDMTracing and MDMScheduler's addTracer: instead.")
FOUNDATION_EXPORT MDMTraceNotificationName _Nonnull MDMTraceNotificationNamePlansCommitted;

/** Data for the MDMTraceNotificationNamePerformersCreated notification. */
__deprecated_msg("Use MDMTracing and MDMScheduler's addTracer: instead.")
NS_SWIFT_NAME(SchedulerPlansCommittedTracePayload)
@interface MDMSchedulerPlansCommittedTracePayload : NSObject

/**
 The set of plans that were committed by the transaction.

 Order matches the transaction's order.
 */
@property(nonatomic, copy, nonnull, readonly) NSArray<MDMPlan>* committedAddPlans;
@property(nonatomic, copy, nonnull, readonly) NSArray<MDMPlan>* committedRemovePlans;

@end

    // clang-format on
