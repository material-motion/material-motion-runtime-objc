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

import UIKit
import MaterialMotionRuntime

// This example demonstrates the development a new plan/performer pair and the committment of the
// plan to a scheduler. We create a "Draggable" plan that enables its associated view to be dragged.
class LifeOfAPlanViewController: UIViewController {

  func commonInit() {
    self.title = "Touch the square to drag it"
  }

  // We create a single Scheduler for the lifetime of this view controller. How many schedulers you
  // decide to create is a matter of preference, but generally speaking it's fair to create one
  // scheduler per self-contained interaction or transition.
  let scheduler = Scheduler()

  // MARK: Configuring views and interactions

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .white

    let squareView = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 100))
    squareView.backgroundColor = .red
    view.addSubview(squareView)

    // Associate a Draggable plan with squareView.
    scheduler.addPlan(Draggable(), to: squareView)
  }

  // MARK: Routing initializers

  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

    self.commonInit()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.commonInit()
  }

  // Let's define a new object, Draggable, that is a type of Plan. Plans must implement two methods:
  //
  // - performerClass(), and
  // - copy(zone:).
  //
  // performerClass() defines which performer class should be instantiated in order to fulfill the
  // plan.
  //
  // copy(zone:) is required by the NSCopying protocol. It is required because plans are copied when
  // they're added to a transaction.
  private class Draggable: NSObject, Plan {
    func performerClass() -> AnyClass {
      return Performer.self
    }
    func copy(with zone: NSZone? = nil) -> Any {
      return Draggable()
    }

    // App code should only ever think in terms of Plan types, so we've made our Performer type a
    // private implementation detail.
    private class Performer: NSObject, Performing {

      // Performers must implement the init(target:) initializer. The target is the object to which
      // the plan was associated and to which the performer should apply modifications.
      let target: UIView
      required init(target: Any) {
        self.target = target as! UIView

        super.init()

        // For this example our performer adds a gesture recognizer to the view. This has the
        // advantage of simplifying our view controller code; associate a Draggable plan with our
        // view and we're done.
        //
        // Some questions to ask:
        //
        // - What if the view already has a gesture recognizer that we'd like to use?
        // - What if we'd like to register the gesture recognizer to a different view?
        //
        // We explore answers to these questions in LifeOfAConfigurablePlan.

        let gestureRecognizer = UIPanGestureRecognizer(target: self,
                                                       action: #selector(didPan(gestureRecognizer:)))
        self.target.addGestureRecognizer(gestureRecognizer)
      }

      // Extract translation values from the pan gesture recognizer and add them to the view's center
      // point.
      var lastTranslation: CGPoint = .zero
      func didPan(gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: target)
        let isActive = gestureRecognizer.state == .began || gestureRecognizer.state == .changed
        if isActive {
          let delta = CGPoint(x: translation.x - lastTranslation.x,
                              y: translation.y - lastTranslation.y)
          target.center = target.center + delta
          lastTranslation = translation
        } else {
          lastTranslation = .zero
        }
      }
    }
  }
}

// Enables `target.center + delta`
private func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
  return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
