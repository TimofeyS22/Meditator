import Intents
import UIKit

/// Donates Siri Shortcuts for common meditation actions.
/// Called from AppDelegate after launch.
class SiriShortcuts {
    
    static func donateAll() {
        donateStartMeditation()
        donateBreathingExercise()
        donateTimerMeditation()
    }
    
    static func donateStartMeditation() {
        let activity = NSUserActivity(activityType: "com.meditatorapp.meditator.startMeditation")
        activity.title = "Начать медитацию"
        activity.suggestedInvocationPhrase = "Начни медитацию"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.userInfo = ["route": "/ai-play?duration=10"]
        activity.persistentIdentifier = "com.meditatorapp.meditator.startMeditation"
        activity.becomeCurrent()
    }
    
    static func donateBreathingExercise() {
        let activity = NSUserActivity(activityType: "com.meditatorapp.meditator.breathe")
        activity.title = "Дыхательное упражнение"
        activity.suggestedInvocationPhrase = "Дыхательное упражнение"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.userInfo = ["route": "/breathe?id=box"]
        activity.persistentIdentifier = "com.meditatorapp.meditator.breathe"
        activity.becomeCurrent()
    }
    
    static func donateTimerMeditation() {
        let activity = NSUserActivity(activityType: "com.meditatorapp.meditator.timer")
        activity.title = "Таймер медитации"
        activity.suggestedInvocationPhrase = "Таймер медитации"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.userInfo = ["route": "/timer"]
        activity.persistentIdentifier = "com.meditatorapp.meditator.timer"
        activity.becomeCurrent()
    }
}
