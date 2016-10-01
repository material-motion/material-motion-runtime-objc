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
 A class conforming to MDMPerforming is expected to implement the plan of motion described by objects
 that conform to MDMPlan.
 */
NS_SWIFT_NAME(Performing)
@protocol MDMPerforming <NSObject>

#pragma mark Designated initializer

/** The receiver is expected to execute its plan to the provided target. */
- (nonnull instancetype)initWithTarget:(nonnull id)target;

@end

@class MDMTransaction;
@protocol MDMPlan;
@protocol MDMNamedPlan;

/** A class conforming to this protocol will be provided with plan instances. */

NS_SWIFT_NAME(PlanPerforming)
@protocol MDMPlanPerforming <MDMPerforming>

#pragma mark Adding plans to a performer

/**
 Provides the performer with a plan.

 The performer may choose to store this plan or to simply extract necessary information and cache
 it separately.

 @param plan The plan that required this type of performer.
 */
- (void)addPlan:(nonnull id<MDMPlan>)plan
    NS_SWIFT_NAME(add(plan:));

@end

/** Specifics for a named plan performer to allow named plans to be added and removed. */
NS_SWIFT_NAME(NamedPlanPerforming)
@protocol MDMNamedPlanPerforming <MDMPerforming>

/**
 Provides the performer with a plan and an associated name.
 
 @param plan The plan that required this type of performer.
 @param name The name by which the plan can be identified.
 */
- (void)addPlan:(nonnull id<MDMNamedPlan>)plan
          named:(nonnull NSString *)name
    NS_SWIFT_NAME(addPlan(_:named:));

/**
 Removes a named plan from a performer.
 
 @param name The name by which the plan can be identified.
 */
- (void)removePlanNamed:(nonnull NSString *)name
    NS_SWIFT_NAME(removePlan(named:));

@end

#pragma mark - Continuous performing

@protocol MDMIsActiveTokenGenerating;

/**
 A performer that conforms to MDMContinuousPerforming is able to request and release is-active
 tokens.

 The scheduler uses these tokens to inform its active state. If any performer owns an is-active
 token then the scheduler is active. Otherwise, the scheduler is idle.

 The performer should store a strong reference to the token generator. Request a token just before
 some continuous work is about to begin, such as adding an animation or starting a gesture
 recognizer. Release the token when the continuous work completes, such as when an animation
 reaches its resting state or when a gesture recognizer is ended or canceled.
 */
NS_SWIFT_NAME(ContinuousPerforming)
@protocol MDMContinuousPerforming <MDMPerforming>

#pragma mark Continuous performing

/**
 Invoked on the performer immediately after initialization.

 If the performer also conforms to MDMPlanPerforming then the token generator will be set before any
 add(plan:) invocations occur.
 */
- (void)setIsActiveTokenGenerator:(nonnull id<MDMIsActiveTokenGenerating>)isActiveTokenGenerator
    NS_SWIFT_NAME(set(isActiveTokenGenerator:));

@end

/**
 A non-terminated is-active token is an indication that some continuous work is active.

 When the continuous work comes to an end, the token should be terminated by invoking terminate. The
 token must then be released. Any further attempts to invoke terminate will result in assertions.

 Tokens will terminate themselves on dealloc if they were not already terminated.
 */
NS_SWIFT_NAME(IsActiveTokenable)
@protocol MDMIsActiveTokenable <NSObject>

#pragma mark Terminating an is-active token

/**
 Remove the token from the pool of active tokens in the scheduler.

 Subsequent invocations of this method will result in an assertion.
 */
- (void)terminate;

@end

/** An is-active token generator is able to generate any number of MDMIsActiveToken instances. */
NS_SWIFT_NAME(IsActiveTokenGenerating)
@protocol MDMIsActiveTokenGenerating <NSObject>

/**
 Generate and return a new is-active token.

 The receiver of this token is expected to eventually invoke terminate on the token.

 May fail to generate a token if the performer's scheduler has been deallocated.
 */
- (nullable id<MDMIsActiveTokenable>)generate;

@end

#pragma mark - Composition

/**
 A plan emitter allows an object to emit new plans to a backing scheduler for the target to which
 the performer is associated.
 */
NS_SWIFT_NAME(PlanEmitting)
@protocol MDMPlanEmitting <NSObject>

/** Emit a new plan. The plan will immediately be added to the backing scheduler. */
- (void)emitPlan:(nonnull NSObject<MDMPlan> *)plan
    NS_SWIFT_NAME(emitPlan(_:));

@end

// clang-format off
/** A transaction emitter allows a performer to commit new plans to a scheduler. */
__deprecated_msg("Use PlanEmitting instead.")
NS_SWIFT_NAME(TransactionEmitting)
@protocol MDMTransactionEmitting <NSObject>

/** Emit a new transaction. The transaction will immediately be committed to the scheduler. */
- (void)emitTransaction:(nonnull MDMTransaction*)transaction
    NS_SWIFT_NAME(emit(transaction:))
    __deprecated_msg("Use PlanEmitting instead.");

@end

/** A class conforming to MDMComposablePerforming is able to commit new plans. */
NS_SWIFT_NAME(ComposablePerforming)
@protocol MDMComposablePerforming <MDMPerforming>

@optional

#pragma mark Composable performing

@optional // TODO: Make required after next release.

/** The performer is provided a plan emitter shortly after initialization. */
- (void)setPlanEmitter:(nonnull id<MDMPlanEmitting>)planEmitter
    NS_SWIFT_NAME(setPlanEmitter(_:));

@optional

/** The performer will be provided with a method for initiating a new transaction. */
- (void)setTransactionEmitter:(nonnull id<MDMTransactionEmitting>)transactionEmitter
    NS_SWIFT_NAME(set(transactionEmitter:))
__deprecated_msg("Use setPlanEmitter instead.");

@end
    // clang-format on
