import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(_ application: UIApplication,
					 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		
#if DEBUG
		let providerFactory = AppCheckDebugProviderFactory()
		AppCheck.setAppCheckProviderFactory(providerFactory)
#else
		let providerFactory = YourSimpleAppCheckProviderFactory()
		AppCheck.setAppCheckProviderFactory(providerFactory)
#endif
		FirebaseApp.configure()
		return true
	}
	
}

class YourSimpleAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
	return AppAttestProvider(app: app)
  }
}



