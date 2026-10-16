import Foundation
import MiseShared

/// The menus and people from design/DIRECTION.md ("Content"), for development
/// and screenshots. Launch with `-seedMenu 1` (Auntie Nid's, Thai, Els selected),
/// `-seedMenu 2` (Trattoria da Carmelo, Sam, vegetarian tonight) or
/// `-seedMenu 3` (Jay Daeng's on a weak signal: drawn plates, no photos yet).
///
/// Photos are Wikimedia Commons files, the first tier of the real image chain.
enum SeedData {
    static let els = Profile(
        id: UUID(uuidString: "E1500000-0000-4000-8000-000000000001")!,
        name: "Els", allergens: [.peanuts, .shellfish], avoids: ["pork"],
        maxSpice: .hot, severe: true, speech: .feminine)
    static let luc = Profile(
        id: UUID(uuidString: "E1500000-0000-4000-8000-000000000002")!,
        name: "Luc", allergens: [.dairy], maxSpice: .mild, speech: .masculine)
    static let sam = Profile(
        id: UUID(uuidString: "E1500000-0000-4000-8000-000000000003")!,
        name: "Sam", maxSpice: .hot, speech: .masculine)

    static func commons(_ title: String) -> URL {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(encoded)?width=800")!
    }

    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "D1500000-0000-4000-8000-%012d", n))!
    }

    // MARK: Auntie Nid's Kitchen

    static var auntieNids: ParsedMenu {
        let shrimpPaste = LikelyIngredient(
            name: "shrimp paste", allergens: [.shellfish],
            question: "มีกะปิไหม", questionTranslation: "Does it have shrimp paste?")
        let oyster = LikelyIngredient(
            name: "oyster sauce", allergens: [.shellfish],
            question: "ใส่น้ำมันหอยไหม", questionTranslation: "Is there oyster sauce in it?")
        let soups = "Salads and soups", mains = "Mains"
        let dishes: [Dish] = [
            Dish(id: id(1), name: "Tom Kha Gai", originalName: "ต้มข่าไก่",
                 description: "Coconut and galangal soup with chicken.",
                 originalDescription: "ต้มข่าไก่ใส่เห็ดและใบมะกรูด",
                 menuNumber: "02", price: 95, currency: "THB", course: .starter, section: soups,
                 dietaryTags: [.glutenFree], spiceLevel: .mild,
                 ingredients: ["chicken", "coconut milk", "galangal", "lemongrass", "lime leaf", "mushroom", "fish sauce"],
                 isPopular: true, imageURL: commons("Tom kha gai2.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY 2.0", plate: .creamySoup),
            Dish(id: id(2), name: "Som Tam Thai", originalName: "ส้มตำไทย",
                 description: "Pounded green papaya, lime, chili.",
                 originalDescription: "ส้มตำไทยใส่ถั่วลิสงและกุ้งแห้ง",
                 menuNumber: "01", price: 70, currency: "THB", course: .starter, section: soups,
                 allergens: [.peanuts, .shellfish],
                 allergenSources: [.init(allergen: .peanuts, ingredient: "peanuts"),
                                   .init(allergen: .shellfish, ingredient: "dried shrimp")],
                 spiceLevel: .hot,
                 ingredients: ["green papaya", "lime", "chili", "peanuts", "dried shrimp", "fish sauce", "tomato"],
                 imageURL: commons("Som Tam or Thai Green Papaya Salad.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 4.0", plate: .salad),
            Dish(id: id(3), name: "Pineapple fried rice", originalName: "ข้าวผัดสับปะรด",
                 description: "Fried rice with cashews, served in the fruit.",
                 originalDescription: "ข้าวผัดสับปะรดใส่เม็ดมะม่วงหิมพานต์และลูกเกด",
                 menuNumber: "07", price: 130, currency: "THB", course: .main, section: mains,
                 allergens: [.nuts, .egg],
                 allergenSources: [.init(allergen: .nuts, ingredient: "cashews"),
                                   .init(allergen: .egg, ingredient: "egg")],
                 ingredients: ["rice", "pineapple", "egg", "raisins", "cashews", "spring onion"],
                 imageURL: commons("Thai-style Fried Rice in Pineapple.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 3.0", plate: .riceInFruit),
            Dish(id: id(4), name: "Hat Yai fried chicken", originalName: "ไก่ทอดหาดใหญ่",
                 description: "Southern fried chicken, crispy shallots.",
                 originalDescription: "ไก่ทอดสูตรหาดใหญ่ โรยหอมเจียว",
                 menuNumber: "09", price: 90, currency: "THB", course: .main, section: mains,
                 protein: "chicken",
                 ingredients: ["chicken", "shallots", "garlic", "coriander root"],
                 imageURL: commons("Kai thot takhrai.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 3.0", plate: .friedChicken),
            Dish(id: id(5), name: "Green curry, chicken", originalName: "แกงเขียวหวานไก่",
                 description: "Coconut-milk curry with green chili, Thai basil and pea aubergine. One of the hotter curries. Served with rice.",
                 originalDescription: "แกงเขียวหวานไก่ เสิร์ฟพร้อมข้าวสวย",
                 menuNumber: "05", price: 110, currency: "THB", course: .main, section: mains,
                 likelyIngredients: [shrimpPaste], protein: "chicken", spiceLevel: .hot,
                 ingredients: ["chicken", "coconut milk", "green chili", "Thai basil", "pea aubergine", "bamboo shoot", "fish sauce"],
                 imageURL: commons("Thai green chicken curry and roti.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 3.0", plate: .curry),
            Dish(id: id(6), name: "Morning glory", originalName: "ผัดผักบุ้งไฟแดง",
                 description: "Water spinach, garlic, chili.",
                 originalDescription: "ผัดผักบุ้งไฟแดง",
                 menuNumber: "08", price: 60, currency: "THB", course: .main, section: mains,
                 dietaryTags: [.vegetarian], likelyIngredients: [oyster], spiceLevel: .medium,
                 ingredients: ["morning glory", "garlic", "chili", "soybean paste"],
                 imageURL: commons("Pak boong fai daeng.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 3.0", plate: .greens),
            Dish(id: id(7), name: "Pad Thai, prawns", originalName: "ผัดไทยกุ้งสด",
                 description: "Rice noodles, prawns, egg, peanuts.",
                 originalDescription: "ผัดไทยกุ้งสด ใส่ไข่ โรยถั่วลิสง",
                 menuNumber: "04", price: 120, currency: "THB", course: .main, section: mains,
                 allergens: [.peanuts, .shellfish, .egg],
                 allergenSources: [.init(allergen: .peanuts, ingredient: "peanuts"),
                                   .init(allergen: .shellfish, ingredient: "prawns"),
                                   .init(allergen: .egg, ingredient: "egg")],
                 protein: "prawns", spiceLevel: .mild,
                 ingredients: ["rice noodles", "prawns", "egg", "peanuts", "tofu", "bean sprouts", "tamarind"],
                 isPopular: true, imageURL: commons("Phat Thai kung Chang Khien street stall.jpg"),
                 imageCredit: "Photo: Takeaway, CC BY-SA 3.0", plate: .friedNoodles),
            Dish(id: id(8), name: "Steamed sea bass", originalName: "ปลากะพงนึ่งมะนาว",
                 description: "Whole fish, lime, garlic, chili.",
                 originalDescription: "ปลากะพงนึ่งมะนาว",
                 menuNumber: "11", price: 280, currency: "THB", course: .main, section: mains,
                 allergens: [.fish], allergenSources: [.init(allergen: .fish, ingredient: "sea bass")],
                 protein: "sea bass", spiceLevel: .medium,
                 ingredients: ["sea bass", "lime", "garlic", "chili", "coriander"],
                 imageURL: commons("Thai steamed fish with lime juice.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, public domain", plate: .wholeFish),
            Dish(id: id(9), name: "Mango sticky rice", originalName: "ข้าวเหนียวมะม่วง",
                 description: "Sticky rice, ripe mango, coconut cream.",
                 originalDescription: "ข้าวเหนียวมะม่วง ราดกะทิ",
                 menuNumber: "14", price: 85, currency: "THB", course: .dessert, section: "Sweet",
                 dietaryTags: [.vegetarian, .vegan],
                 ingredients: ["sticky rice", "mango", "coconut cream", "sesame"],
                 imageURL: commons("Mango sticky rice served in Thailand.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY 4.0", plate: .sweet),
            Dish(id: id(10), name: "Fresh coconut", originalName: "น้ำมะพร้าว",
                 description: "Young coconut, chilled.",
                 menuNumber: "15", price: 40, currency: "THB", course: .drink, section: "Drinks",
                 dietaryTags: [.vegetarian, .vegan], ingredients: ["coconut"],
                 imageURL: commons("Fresh Thai drinking coconut Mohammad Nemat Zadeh.jpg"),
                 imageCredit: "Photo: Mohammad Nemat Zadeh, CC0", plate: .coconut),
            Dish(id: id(11), name: "Thai iced tea", originalName: "ชาเย็น",
                 description: "Strong black tea with condensed milk, over ice.",
                 menuNumber: "16", price: 45, currency: "THB", course: .drink, section: "Drinks",
                 dietaryTags: [.vegetarian], allergens: [.dairy],
                 allergenSources: [.init(allergen: .dairy, ingredient: "condensed milk")],
                 ingredients: ["black tea", "condensed milk", "sugar"],
                 imageURL: commons("Cha-Yen (Thai iced tea) - Namo 2026-07-30.jpg"),
                 imageCredit: "Photo: Namo, CC0", plate: .drink),
        ]
        return ParsedMenu(
            id: UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!,
            restaurantName: "Auntie Nid's Kitchen", originalRestaurantName: "ครัวป้านิด",
            cuisine: "Thai", sourceLanguage: "th", currency: "THB",
            exchange: ExchangeRate(home: "EUR", perHome: Decimal(string: "37.6")!, fetchedAt: .now),
            scannedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now),
            dishes: dishes)
    }

    // MARK: Trattoria da Carmelo

    static var carmelo: ParsedMenu {
        let rennet = LikelyIngredient(
            name: "animal rennet", breaks: [.vegetarian, .vegan],
            question: "Il parmigiano è con caglio animale?",
            questionTranslation: "Is the parmigiano made with animal rennet?",
            note: "Parmigiano uses animal rennet")
        let dishes: [Dish] = [
            Dish(id: id(101), name: "Sweet-sour aubergine", originalName: "Caponata",
                 description: "Sweet-sour aubergine stew with celery, olives and capers.",
                 originalDescription: "Melanzane, sedano, olive, capperi in agrodolce",
                 menuNumber: "02", price: 8, currency: "EUR", course: .starter, section: "Antipasti",
                 dietaryTags: [.vegetarian, .vegan],
                 ingredients: ["aubergine", "celery", "olives", "capers", "tomato", "vinegar"],
                 imageURL: commons("Caponata nissena.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 4.0", plate: .greens),
            Dish(id: id(102), name: "Fried rice ball", originalName: "Arancino al ragù",
                 description: "Saffron rice ball filled with meat ragù and peas, fried.",
                 originalDescription: "Arancino con ragù di carne e piselli",
                 menuNumber: "01", price: Decimal(string: "3.5")!, currency: "EUR", course: .starter, section: "Antipasti",
                 allergens: [.gluten, .dairy], protein: "meat ragù",
                 ingredients: ["rice", "saffron", "beef ragù", "peas", "breadcrumbs", "caciocavallo"],
                 imageURL: commons("Arancini - Caltanissetta, Sicilia.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY 2.0", plate: .friedChicken),
            Dish(id: id(103), name: "Aubergine pasta", originalName: "Pasta alla Norma",
                 description: "Tomato, fried aubergine, salted ricotta.",
                 originalDescription: "Pomodoro, melanzane fritte, ricotta salata, basilico",
                 menuNumber: "05", price: 12, currency: "EUR", course: .main, section: "Primi",
                 dietaryTags: [.vegetarian], allergens: [.gluten, .dairy],
                 ingredients: ["pasta", "tomato", "aubergine", "ricotta salata", "basil"],
                 isPopular: true, imageURL: commons("Pasta alla Norma - Wiki Loves Sicilia.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC0", plate: .friedNoodles),
            Dish(id: id(104), name: "Egg pasta, meat", originalName: "Tagliatelle al ragù",
                 description: "Egg tagliatelle in a slow beef and pork ragù.",
                 originalDescription: "Tagliatelle all'uovo, ragù di manzo e maiale",
                 menuNumber: "06", price: 14, currency: "EUR", course: .main, section: "Primi",
                 dietaryTags: [.containsPork], allergens: [.gluten, .egg, .dairy], protein: "beef and pork",
                 ingredients: ["egg pasta", "beef", "pork", "tomato", "parmigiano"],
                 imageURL: commons("Tagliatelle al ragù 03.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 3.0", plate: .friedNoodles),
            Dish(id: id(105), name: "Aubergine bake", originalName: "Parmigiana",
                 description: "Aubergine baked with tomato and cheese.",
                 originalDescription: "Melanzane, pomodoro, mozzarella, parmigiano",
                 menuNumber: "09", price: 11, currency: "EUR", course: .main, section: "Secondi",
                 dietaryTags: [.vegetarian], allergens: [.dairy], likelyIngredients: [rennet],
                 ingredients: ["aubergine", "tomato", "mozzarella", "parmigiano", "basil"],
                 imageURL: commons("Parmigiana di melanzane.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 4.0", plate: .curry),
            Dish(id: id(106), name: "Swordfish rolls", originalName: "Involtini di spada",
                 description: "Thin swordfish rolled round breadcrumbs, pine nuts and raisins.",
                 originalDescription: "Involtini di pesce spada alla messinese",
                 menuNumber: "11", price: 18, currency: "EUR", course: .main, section: "Secondi",
                 allergens: [.fish, .gluten, .nuts], protein: "fish",
                 ingredients: ["swordfish", "breadcrumbs", "pine nuts", "raisins", "lemon"],
                 plate: .fishRolls),
            Dish(id: id(107), name: "Ricotta pastry", originalName: "Cannoli",
                 description: "Crisp shells filled with sweet ricotta and pistachio.",
                 originalDescription: "Cannoli siciliani con ricotta di pecora",
                 menuNumber: "14", price: 5, currency: "EUR", course: .dessert, section: "Dolci",
                 dietaryTags: [.vegetarian], allergens: [.gluten, .dairy, .nuts],
                 ingredients: ["ricotta", "pistachio", "candied orange"],
                 imageURL: commons("Cannoli siciliani on a plate.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY-SA 2.0", plate: .sweet),
            Dish(id: id(108), name: "Coffee, mascarpone", originalName: "Tiramisù",
                 description: "Coffee-soaked savoiardi under mascarpone and cocoa.",
                 menuNumber: "15", price: 6, currency: "EUR", course: .dessert, section: "Dolci",
                 dietaryTags: [.vegetarian, .containsAlcohol], allergens: [.gluten, .dairy, .egg],
                 ingredients: ["savoiardi", "coffee", "mascarpone", "cocoa", "marsala"],
                 imageURL: commons("Dolce Tiramisù monoporzione.jpg"),
                 imageCredit: "Photo: Wikimedia Commons, CC BY 4.0", plate: .sweet),
        ]
        return ParsedMenu(
            id: UUID(uuidString: "A0000000-0000-4000-8000-000000000002")!,
            restaurantName: "Trattoria da Carmelo", cuisine: "Italian", place: "Ortigia, Siracusa",
            sourceLanguage: "it", currency: "EUR", scannedAt: .now, dishes: dishes)
    }

    // MARK: Jay Daeng's (photos still loading)

    static var jayDaeng: ParsedMenu {
        let noodles = "Rice and noodles"
        let dishes: [Dish] = [
            Dish(id: id(201), name: "Khao man gai", originalName: "ข้าวมันไก่",
                 description: "Poached chicken on rice cooked in its stock.",
                 menuNumber: "01", price: 60, currency: "THB", course: .main, section: noodles,
                 protein: "chicken", ingredients: ["chicken", "rice", "ginger", "soy sauce"], plate: .chickenRice),
            Dish(id: id(202), name: "Kuay teow nam", originalName: "ก๋วยเตี๋ยวน้ำ",
                 description: "Rice-noodle soup, meatballs, bean sprouts.",
                 menuNumber: "02", price: 55, currency: "THB", course: .main, section: noodles,
                 protein: "beef meatballs", ingredients: ["rice noodles", "beef meatballs", "bean sprouts"],
                 plate: .noodleSoup),
            Dish(id: id(203), name: "Pad kra pao, pork", originalName: "ผัดกะเพราหมู",
                 description: "Minced pork with holy basil and a fried egg.",
                 menuNumber: "03", price: 65, currency: "THB", course: .main, section: noodles,
                 dietaryTags: [.containsPork], allergens: [.egg], protein: "pork", spiceLevel: .hot,
                 ingredients: ["pork", "holy basil", "chili", "egg"], plate: .riceWithEgg),
            Dish(id: id(205), name: "Khao pad", originalName: "ข้าวผัด",
                 description: "Fried rice with egg and spring onion.",
                 menuNumber: "05", price: 60, currency: "THB", course: .main, section: noodles,
                 allergens: [.egg], ingredients: ["rice", "egg", "spring onion"], plate: .friedRice),
            Dish(id: id(204), name: "Tom yum goong", originalName: "ต้มยำกุ้ง",
                 description: "Hot and sour soup with prawns and lemongrass.",
                 menuNumber: "04", price: 120, currency: "THB", course: .starter, section: "Soups",
                 allergens: [.shellfish], allergenSources: [.init(allergen: .shellfish, ingredient: "shrimp")],
                 protein: "shrimp", spiceLevel: .hot,
                 ingredients: ["shrimp", "lemongrass", "galangal", "lime", "chili"], plate: .spicySoup),
            Dish(id: id(206), name: "Jok", originalName: "โจ๊ก",
                 description: "Rice porridge with ginger and egg.",
                 menuNumber: "06", price: 45, currency: "THB", course: .starter, section: "Soups",
                 allergens: [.egg], ingredients: ["rice", "ginger", "egg", "spring onion"], plate: .porridge),
        ]
        return ParsedMenu(
            id: UUID(uuidString: "A0000000-0000-4000-8000-000000000003")!,
            restaurantName: "Jay Daeng's", originalRestaurantName: "ร้านเจ๊แดง",
            cuisine: "Thai", sourceLanguage: "th", currency: "THB",
            exchange: ExchangeRate(home: "EUR", perHome: Decimal(string: "37.6")!, fetchedAt: .now),
            scannedAt: .now, dishes: dishes)
    }

    static var jokPrince: ParsedMenu {
        var menu = ParsedMenu(
            id: UUID(uuidString: "A0000000-0000-4000-8000-000000000004")!,
            restaurantName: "Jok Prince", originalRestaurantName: "โจ๊กปรินซ์",
            cuisine: "Thai", sourceLanguage: "th", currency: "THB",
            scannedAt: Calendar.current.date(byAdding: .day, value: -4, to: .now),
            dishes: jayDaeng.dishes.suffix(1) + [])
        menu.dishes[0].imageURL = commons("Jok mu sap.JPG")
        return menu
    }
}
