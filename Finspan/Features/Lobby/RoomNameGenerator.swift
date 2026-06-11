import Foundation

enum RoomNameGenerator {
    static let names = [
        "小丑鱼礁",
        "灯笼鱼湾",
        "海马观察站",
        "翻车鱼潜点",
        "鲨鱼巡游区",
        "珊瑚夜航",
        "蓝鳍浅滩",
        "海葵小站"
    ]

    static func name(at index: Int) -> String {
        names[index % names.count]
    }
}
