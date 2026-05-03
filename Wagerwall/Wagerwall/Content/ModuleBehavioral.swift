import Foundation

/// Module 3: Behavioral Strategies.
/// Practical skills and habits to replace gambling and prevent relapse.
enum ModuleBehavioral {

    static let module = Module(
        id: "module-behavioral",
        title: "Behavioral Strategies",
        description: "Build practical skills and habits to replace gambling and prevent relapse.",
        sortOrder: 3,
        estimatedMinutes: 40,
        iconName: "figure.walk"
    )

    // MARK: - Lessons

    static let lessons: [Lesson] = [
        lessonHighRiskSituations,
        lessonAlternativeActivities,
        lessonRelapsePrevention,
    ]

    private static let lessonHighRiskSituations = Lesson(
        id: "lesson-high-risk-situations",
        moduleId: module.id,
        title: "Avoiding High-Risk Situations",
        description: "Learn to identify and manage situations that put your recovery at risk.",
        sortOrder: 1,
        estimatedMinutes: 14,
        sections: [
            .text(title: "High-Risk Situations", body: """
            A high-risk situation is any circumstance that significantly increases your urge to gamble. In early recovery, avoiding these situations when possible is not weakness — it's smart strategy.

            Think of it like someone with a food allergy avoiding restaurants that can't accommodate them. It's not about willpower; it's about setting yourself up for success.
            """),
            .text(title: "Common High-Risk Situations", body: """
            **Places**: Casinos, betting shops, racetracks, bars with gambling machines

            **Times**: Payday, late at night when bored, weekends with unstructured time

            **People**: Friends who gamble, people who owe you money or whom you owe

            **Emotional states**: The HALT acronym — Hungry, Angry, Lonely, Tired

            **Digital**: Gambling apps on your phone, gambling websites, sports scores notifications
            """),
            .callout(style: .tip, body: "Use WagerWall's app and website blocking to remove digital high-risk situations. Technology can be a powerful ally in recovery."),
            .text(title: "Creating a Safety Plan", body: """
            For situations you can't avoid, prepare in advance:

            1. **Identify the situation** in advance
            2. **Plan your response** before you're in it
            3. **Have an exit strategy** ready
            4. **Tell someone** about your plan
            5. **Review what worked** afterward
            """),
            .question("q-halt-acronym"),
            .journal(prompt: "Map out your typical week. Identify your top 3 high-risk situations and write a specific plan for how you will handle each one."),
        ]
    )

    private static let lessonAlternativeActivities = Lesson(
        id: "lesson-alternative-activities",
        moduleId: module.id,
        title: "Building Alternative Activities",
        description: "Discover fulfilling activities to fill the void that gambling leaves.",
        sortOrder: 2,
        estimatedMinutes: 13,
        sections: [
            .text(title: "The Void Gambling Leaves", body: """
            Gambling doesn't just take money — it takes time, social connection, excitement, and a sense of purpose. When you stop gambling, you may feel a significant void. If you don't fill that void with something meaningful, the pull back to gambling becomes much stronger.

            The good news: the same brain that got hooked on gambling can learn to find reward in healthier activities.
            """),
            .text(title: "What Gambling Gave You (And Alternatives)", body: """
            **Excitement/thrill**: Try rock climbing, competitive sports, video games, cooking challenges, learning a musical instrument

            **Social connection**: Join a club, volunteer, attend support groups, reconnect with friends you lost touch with

            **Escape from problems**: Exercise, meditation, therapy, journaling, creative arts

            **Sense of achievement**: Set fitness goals, learn new skills, take on projects at work, start a garden

            **Extra money (perceived)**: Create a realistic budget, start a side project, invest in index funds
            """),
            .callout(style: .tip, body: "Start small. You don't need to overhaul your entire life at once. Pick ONE activity that appeals to you and commit to trying it this week."),
            .question("q-alternatives-purpose"),
            .journal(prompt: "What did gambling provide for you emotionally? List 3 needs it met, then brainstorm 2 healthy alternatives for each need. Pick one to try this week."),
        ]
    )

    private static let lessonRelapsePrevention = Lesson(
        id: "lesson-relapse-prevention",
        moduleId: module.id,
        title: "Relapse Prevention Planning",
        description: "Create a personal plan to maintain your recovery long-term.",
        sortOrder: 3,
        estimatedMinutes: 13,
        sections: [
            .text(title: "Relapse is a Process, Not an Event", body: """
            Relapse doesn't happen the moment you place a bet. It's a process that starts days or weeks earlier with emotional and cognitive changes:

            1. **Emotional relapse**: You stop taking care of yourself. Poor sleep, isolation, skipping support activities, bottling up emotions.
            2. **Mental relapse**: Part of you wants to gamble. You start romanticizing past gambling, thinking "just once" would be okay, or planning how you could gamble without getting caught.
            3. **Physical relapse**: You actually gamble.

            The earlier in this process you intervene, the easier it is to get back on track.
            """),
            .callout(style: .warning, body: "If you do relapse, it does NOT erase your progress. Many people in recovery experience setbacks. What matters is what you do next. A slip doesn't have to become a slide."),
            .text(title: "Your Prevention Plan", body: """
            A strong relapse prevention plan includes:

            **Daily practices**: Regular check-ins with WagerWall, mood logging, maintaining routines

            **Warning signs**: Know YOUR early signs (sleep changes, irritability, isolation, financial stress)

            **Coping tools**: Breathing exercises, calling your accountability partner, using the panic button, journaling

            **Emergency contacts**: Therapist, sponsor, support group, crisis helpline (1-800-522-4700)

            **If I slip**: Specific steps — stop gambling immediately, call someone, log the slip honestly, attend a support meeting, identify what happened, adjust your plan
            """),
            .question("q-relapse-first-stage"),
            .journal(prompt: "Create your personal relapse prevention plan. List: (1) Your top 3 warning signs, (2) Your top 3 coping tools, (3) Three people you can call in a crisis, (4) What you will do if you slip."),
        ]
    )

    // MARK: - Questions

    static let questions: [Question] = [
        // Lesson 3.1 quiz + practice
        Question(
            id: "q-halt-acronym",
            moduleId: module.id,
            tags: ["halt", "high-risk"],
            difficulty: 1,
            prompt: "What does the HALT acronym stand for in recovery?",
            explanation: "HALT stands for Hungry, Angry, Lonely, Tired. These four states make you especially vulnerable to urges. When you feel an urge, check if any of these apply and address the underlying need first.",
            payload: .multipleChoice(
                options: [
                    "Help, Accept, Learn, Trust",
                    "Hungry, Angry, Lonely, Tired",
                    "Hope, Awareness, Love, Truth",
                    "Heal, Achieve, Live, Thrive",
                ],
                correctIndex: 1
            )
        ),

        // Lesson 3.2 quiz + practice
        Question(
            id: "q-alternatives-purpose",
            moduleId: module.id,
            tags: ["alternatives", "recovery"],
            difficulty: 1,
            prompt: "Why is it important to find alternative activities when quitting gambling?",
            explanation: "The key isn't just distraction or busyness — it's finding healthy ways to meet the same underlying needs (excitement, connection, escape, achievement) that gambling was filling.",
            payload: .multipleChoice(
                options: [
                    "To distract yourself so you never think about gambling",
                    "To fill the needs that gambling was meeting in healthier ways",
                    "To prove to others that you've changed",
                    "To stay so busy you don't have time to gamble",
                ],
                correctIndex: 1
            )
        ),

        // Lesson 3.3 quiz + practice
        Question(
            id: "q-relapse-first-stage",
            moduleId: module.id,
            tags: ["relapse", "stages"],
            difficulty: 2,
            prompt: "What is typically the FIRST stage of relapse?",
            explanation: "Emotional relapse comes first. When you stop taking care of yourself — poor sleep, isolation, skipping healthy routines — you become vulnerable to mental relapse (thinking about gambling), which can then lead to physical relapse.",
            payload: .multipleChoice(
                options: [
                    "Physical relapse (placing a bet)",
                    "Mental relapse (thinking about gambling)",
                    "Emotional relapse (poor self-care, isolation)",
                    "Financial relapse (running out of money)",
                ],
                correctIndex: 2
            )
        ),

        // Practice T/F: avoiding high risk
        Question(
            id: "q-avoiding-high-risk-tf",
            moduleId: module.id,
            tags: ["high-risk", "recovery"],
            difficulty: 1,
            prompt: "Avoiding high-risk situations in early recovery is a sign of weakness.",
            explanation: "Avoiding high-risk situations is a smart recovery strategy, not weakness. It's like someone with a food allergy avoiding unsafe restaurants — you're setting yourself up for success.",
            payload: .trueFalse(answer: false)
        ),

        // Practice T/F: relapse as process
        Question(
            id: "q-relapse-process-tf",
            moduleId: module.id,
            tags: ["relapse", "stages"],
            difficulty: 1,
            prompt: "Relapse is a process that starts well before you actually place a bet.",
            explanation: "Relapse starts with emotional changes (poor self-care, isolation) days or weeks before you gamble. Recognizing early warning signs lets you intervene before things escalate.",
            payload: .trueFalse(answer: true)
        ),

        // Practice T/F: slip erases progress
        Question(
            id: "q-slip-erases-progress",
            moduleId: module.id,
            tags: ["relapse", "recovery"],
            difficulty: 1,
            prompt: "If you relapse once, all your recovery progress is permanently lost.",
            explanation: "A slip doesn't erase your progress. Many people in recovery experience setbacks. What matters most is how you respond — stop immediately, reach out for support, and learn from what happened.",
            payload: .trueFalse(answer: false)
        ),

        // Practice matching: needs to alternatives
        Question(
            id: "q-needs-alternatives-match",
            moduleId: module.id,
            tags: ["alternatives", "recovery"],
            difficulty: 2,
            prompt: "Match each need gambling fills to a healthy alternative:",
            explanation: "Finding activities that meet the same underlying needs as gambling is key to sustainable recovery. The goal isn't just distraction — it's genuine fulfillment.",
            payload: .matching(pairs: [
                .init("Excitement & thrill", "Rock climbing or competitive sports"),
                .init("Social connection", "Volunteering or joining a club"),
                .init("Escape from stress", "Exercise or meditation"),
                .init("Sense of achievement", "Learning a new skill or hobby"),
            ])
        ),

        // Practice matching: relapse stages
        Question(
            id: "q-relapse-stages-match",
            moduleId: module.id,
            tags: ["relapse", "stages"],
            difficulty: 2,
            prompt: "Match each relapse stage to its warning signs:",
            explanation: "The earlier you recognize which stage you're in, the easier it is to get back on track. Emotional relapse is the best time to intervene.",
            payload: .matching(pairs: [
                .init("Emotional relapse", "Poor sleep, isolation, bottled emotions"),
                .init("Mental relapse", "Romanticizing past gambling, planning bets"),
                .init("Physical relapse", "Actually placing a bet or entering a casino"),
            ])
        ),

        // MultipleSelect: HALT components
        Question(
            id: "q-halt-components-ms",
            moduleId: module.id,
            tags: ["halt", "high-risk"],
            difficulty: 1,
            prompt: "HALT highlights four states that make you vulnerable to urges. Select all four.",
            explanation: "HALT = Hungry, Angry, Lonely, Tired. When any of these is present, your impulse-control resources are drained — address the underlying need before responding to an urge.",
            payload: .multipleSelect(
                options: [
                    "Hungry",
                    "Angry",
                    "Hopeful",
                    "Lonely",
                    "Tired",
                    "Lucky",
                ],
                correctIndices: [0, 1, 3, 4]
            )
        ),

        // MultipleSelect: needs that gambling fills
        Question(
            id: "q-alternatives-needs-ms",
            moduleId: module.id,
            tags: ["alternatives", "recovery"],
            difficulty: 2,
            prompt: "Which underlying needs does gambling typically fill? Select all that apply.",
            explanation: "Gambling tends to meet needs for excitement, escape, social connection, and a sense of achievement. Sustainable recovery means meeting those same needs in healthier ways.",
            payload: .multipleSelect(
                options: [
                    "Excitement and thrill",
                    "A balanced diet",
                    "Escape from stress",
                    "Social connection",
                    "Sense of achievement",
                ],
                correctIndices: [0, 2, 3, 4]
            )
        ),

        // FillInBlank freeType: relapse stage names in order
        Question(
            id: "q-relapse-stages-fillin",
            moduleId: module.id,
            tags: ["relapse", "stages"],
            difficulty: 2,
            prompt: "Complete the three stages of relapse, in order.",
            explanation: "Relapse moves through emotional → mental → physical stages. The earlier you recognize the stage, the easier it is to interrupt before you actually gamble.",
            payload: .fillInBlank(
                template: "___ relapse, then ___ relapse, then ___ relapse.",
                acceptedAnswers: [
                    ["emotional"],
                    ["mental"],
                    ["physical"],
                ],
                mode: .freeType
            )
        ),

        // FillInBlank wordBank: HALT components
        Question(
            id: "q-halt-fillin",
            moduleId: module.id,
            tags: ["halt"],
            difficulty: 1,
            prompt: "Tap the missing letters of HALT.",
            explanation: "HALT stands for Hungry, Angry, Lonely, Tired — four vulnerability states to check during an urge.",
            payload: .fillInBlank(
                template: "HALT = ___, ___, Lonely, Tired.",
                acceptedAnswers: [
                    ["hungry"],
                    ["angry"],
                ],
                mode: .wordBank(words: ["hungry", "angry", "happy", "anxious", "lucky"])
            )
        ),

        // SortOrder: relapse stages
        Question(
            id: "q-relapse-stages-sort",
            moduleId: module.id,
            tags: ["relapse", "stages"],
            difficulty: 2,
            prompt: "Order the stages of relapse from earliest to latest.",
            explanation: "Emotional relapse comes first (poor self-care, isolation), then mental relapse (romanticizing gambling, planning), then physical relapse (placing a bet). The earlier you intervene, the easier it is to recover.",
            payload: .sortOrder(items: [
                "Emotional relapse",
                "Mental relapse",
                "Physical relapse",
            ])
        ),

        // SwipeCategorize: high-risk vs. safer choices
        Question(
            id: "q-high-risk-swipe",
            moduleId: module.id,
            tags: ["high-risk", "recovery"],
            difficulty: 2,
            prompt: "Sort each situation: high-risk, or relatively safe in early recovery?",
            explanation: "High-risk situations materially raise the chance of gambling. Avoiding them in early recovery isn't weakness — it's strategy. Safer choices fill the same time/social need without the gambling exposure.",
            payload: .swipeCategorize(
                leftLabel: "Safer choice",
                rightLabel: "High-risk",
                cards: [
                    .init(text: "Going to a sports bar with gambling friends", correctSide: .right),
                    .init(text: "Joining a hiking group", correctSide: .left),
                    .init(text: "Late-night scrolling on a betting app", correctSide: .right),
                    .init(text: "Dinner with non-gambling friends", correctSide: .left),
                    .init(text: "Visiting a casino 'just to look'", correctSide: .right),
                    .init(text: "Going to a Gamblers Anonymous meeting", correctSide: .left),
                ]
            )
        ),
    ]
}
