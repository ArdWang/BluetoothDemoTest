//
//  ContentView.swift
//  BluetoothDemoTest
//
//  Created by RND on 2021/2/2.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
            .environmentObject(Store.shared)
            .onAppear{
                Store.shared.run()
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
