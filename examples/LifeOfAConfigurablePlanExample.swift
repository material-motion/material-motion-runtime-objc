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

// This example demonstrates how to configure a performer using properties on a plan. We recreate
// the Draggable plan found in Life of a Plan, but this time with a configurable
// panGestureRecognizer property. We assign a pre-made pan gesture recognizer that's already
// associated with the view controller's root view, allowing us to drag the square by touching
// anywhere in the view controller.
class LifeOfAConfigurablePlanViewController: UIViewController {
  let scheduler = Scheduler()

  func commonInit() {
    self.title = "Touch anywhere to drag the square"
  }

  // MARK: Configuring views and interactions

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .white

    let squareView = UIView(frame: CGRect(x: 100, y: 200, width: 100, height: 100))
    squareView.backgroundColor = .red
    view.addSubview(squareView)

    // Note that we're adding the pan gesture recognizer to our view controller's root view and
    // providing the gesture recognizer to our plan.
    let panGestureRecognizer = UIPanGestureRecognizer()
    view.addGestureRecognizer(panGestureRecognizer)

    scheduler.addPlan(Draggable(panGestureRecognizer: panGestureRecognizer), to: squareView)
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
}

class Draggable: NSObject, Plan {
  var panGestureRecognizer: UIPanGestureRecognizer?

  init(panGestureRecognizer: UIPanGestureRecognizer) {
    self.panGestureRecognizer = panGestureRecognizer

    super.init()
  }
  override init() {
    super.init()
  }

  func performerClass() -> AnyClass {
    return Performer.self
  }
  func copy(with zone: NSZone? = nil) -> Any {
    let copy = Draggable()
    copy.panGestureRecognizer = panGestureRecognizer
    return copy
  }

  // Our performer now conforms to PlanPerforming. This allows our performer to receive plan
  // instances as they are committed.
  //
  // Note that PlanPerforming also conforms to Performing; we don't need to conform to it
  // explicitly.
  private class Performer: NSObject, PlanPerforming {
    let target: UIView
    required init(target: Any) {
      self.target = target as! UIView
      super.init()
    }

    func addPlan(_ plan: Plan) {
      // We must downcast our plan to the expected type in order to access its properties. We use
      // ! to enforce this expectation at runtime.
      let draggable = plan as! Draggable

      let selector = #selector(didPan(gestureRecognizer:))

      if let panGestureRecognizer = draggable.panGestureRecognizer {
        // Listen to this gesture recognizer's events.
        panGestureRecognizer.addTarget(self, action: selector)
      } else {
        // Create a gesture recognizer and associate it with the target.
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: selector)
        self.target.addGestureRecognizer(gestureRecognizer)
      }
    }

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

private func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
  return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
