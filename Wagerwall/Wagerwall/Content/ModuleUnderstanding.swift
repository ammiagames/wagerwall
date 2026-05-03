import Foundation

/// Module 1: Understanding Gambling.
/// Foundational content on what problem gambling is, how it grips us, and what triggers urges.
enum ModuleUnderstanding {

    static let module = Module(
        id: "module-understanding",
        title: "Understanding Gambling",
        description: "Learn about problem gambling, cognitive distortions, and what drives the urge to gamble.",
        sortOrder: 1,
        estimatedMinutes: 30,
        iconName: "brain.head.profile"
    )

    // MARK: - Lessons

    static let lessons: [Lesson] = [
        lessonProblemGambling,
        lessonGamblersFallacy,
        lessonTriggers,
    ]

    private static let lessonProblemGambling = Lesson(
        id: "lesson-problem-gambling",
        moduleId: module.id,
        title: "What is Problem Gambling?",
        description: "Understand the spectrum of gambling behavior and where you might fall.",
        sortOrder: 1,
        estimatedMinutes: 10,
        sections: [
            .text(title: "The Gambling Spectrum", body: """
            Gambling exists on a spectrum. On one end is recreational gambling — an occasional activity done for fun with money you can afford to lose. On the other end is disordered gambling — a compulsive behavior that causes significant harm to your life, relationships, and finances.

            Most people who develop gambling problems didn't start out planning to. It often begins gradually, with wins creating excitement and losses creating a desire to "win it back."
            """),
            .callout(style: .tip, body: "Problem gambling is not about willpower or moral character. It is a recognized behavioral addiction that changes how your brain processes risk and reward."),
            .text(title: "Warning Signs", body: """
            Common signs of problem gambling include:

            • Spending more money or time gambling than intended
            • Chasing losses by gambling more to recover money
            • Lying to others about how much you gamble
            • Feeling restless or irritable when trying to stop
            • Using gambling to escape problems or relieve negative emotions
            • Jeopardizing relationships, jobs, or education because of gambling
            • Borrowing money or selling things to finance gambling
            """),
            .question("q-define-problem-gambling"),
            .journal(prompt: "Reflect on your own gambling history. When did you first notice that gambling was becoming more than just entertainment? What changes did you see in yourself?"),
        ]
    )

    private static let lessonGamblersFallacy = Lesson(
        id: "lesson-gamblers-fallacy",
        moduleId: module.id,
        title: "The Gambler's Fallacy",
        description: "Understand why past outcomes don't predict future results.",
        sortOrder: 2,
        estimatedMinutes: 10,
        sections: [
            .text(title: "What is the Gambler's Fallacy?", body: """
            The Gambler's Fallacy is the mistaken belief that past random events affect future random events. For example, believing that after a coin lands on heads five times in a row, tails is "due" to come up.

            In reality, each coin flip is independent — the coin has no memory. The probability is always 50/50, regardless of what happened before.
            """),
            .callout(style: .example, body: "\"I've lost 8 hands in a row at blackjack. I'm due for a win!\" — This is the Gambler's Fallacy in action. The cards don't know or care about your previous hands."),
            .text(title: "The House Always Has an Edge", body: """
            Every casino game is mathematically designed so that the house wins over time. This is called the house edge.

            • Slot machines: 2-15% house edge
            • Roulette: 2.7-5.3% house edge
            • Blackjack: 0.5-2% house edge
            • Sports betting: ~5% vig built into odds

            No strategy, system, or lucky streak can overcome the house edge in the long run. The longer you play, the more likely you are to lose.
            """),
            .callout(style: .warning, body: "\"Hot streaks\" and \"cold streaks\" are patterns our brains impose on random data. Humans are wired to find patterns — even where none exist."),
            .question("q-roulette-streak-mc"),
        ]
    )

    private static let lessonTriggers = Lesson(
        id: "lesson-triggers",
        moduleId: module.id,
        title: "Your Gambling Triggers",
        description: "Identify the situations, emotions, and thoughts that lead you to gamble.",
        sortOrder: 3,
        estimatedMinutes: 10,
        sections: [
            .text(title: "Understanding Triggers", body: """
            A trigger is anything that creates an urge to gamble. Triggers can be external (situations, places, people) or internal (emotions, thoughts, physical sensations).

            Identifying your personal triggers is one of the most important steps in recovery. When you know what sets off an urge, you can prepare strategies to handle it.
            """),
            .text(title: "Common Trigger Categories", body: """
            **Emotional triggers**: Stress, anxiety, boredom, loneliness, anger, depression, or even excitement and celebration.

            **Environmental triggers**: Passing a casino, seeing gambling ads, being on your phone late at night, visiting a sports bar.

            **Social triggers**: Friends who gamble, peer pressure, social events where gambling happens.

            **Financial triggers**: Getting paid, receiving a tax refund, having unexpected expenses (wanting to "solve" money problems by gambling).

            **Cognitive triggers**: Thinking "just one bet won't hurt," remembering a big win, believing you have a system.
            """),
            .callout(style: .reflection, body: "Recovery isn't about avoiding every trigger forever — it's about recognizing triggers and having a plan to respond differently when they arise."),
            .journal(prompt: "List your top 3 gambling triggers. For each one, describe: (1) What the trigger is, (2) How it makes you feel, (3) One thing you could do instead of gambling when this trigger hits."),
            .question("q-cognitive-trigger-example"),
        ]
    )

    // MARK: - Questions

    static let questions: [Question] = [
        // Lesson 1.1 quiz + practice
        Question(
            id: "q-define-problem-gambling",
            moduleId: module.id,
            tags: ["problem-gambling", "definition"],
            difficulty: 1,
            prompt: "Which of the following best describes problem gambling?",
            explanation: "Problem gambling is a recognized behavioral addiction. Like substance addictions, it involves changes in brain chemistry — particularly in how dopamine and reward pathways function.",
            payload: .multipleChoice(
                options: [
                    "A moral failing that shows lack of discipline",
                    "A behavioral addiction that changes brain reward pathways",
                    "Something that only affects people who gamble daily",
                    "A choice that people can simply stop making",
                ],
                correctIndex: 1
            )
        ),

        // Lesson 1.2 quiz
        Question(
            id: "q-roulette-streak-mc",
            moduleId: module.id,
            tags: ["gamblers-fallacy", "probability"],
            difficulty: 1,
            prompt: "A roulette wheel has landed on red 6 times in a row. What is the probability the next spin lands on black?",
            explanation: "Each spin of the roulette wheel is independent. The wheel has no memory of previous spins. The probability of black is always about 47.4% (18 black out of 38 total slots on an American wheel).",
            payload: .multipleChoice(
                options: [
                    "Much higher than normal — black is overdue",
                    "Slightly higher than normal",
                    "The same as always — about 47.4%",
                    "Lower than normal — red is on a hot streak",
                ],
                correctIndex: 2
            )
        ),

        // Lesson 1.3 quiz + practice
        Question(
            id: "q-cognitive-trigger-example",
            moduleId: module.id,
            tags: ["triggers", "cognitive"],
            difficulty: 1,
            prompt: "Which of the following is an example of a cognitive trigger?",
            explanation: "Cognitive triggers are thoughts and beliefs that lead to gambling. The belief that you have a winning system is a cognitive distortion that creates urges to gamble. The other options are emotional, environmental, and social triggers respectively.",
            payload: .multipleChoice(
                options: [
                    "Feeling stressed after a hard day at work",
                    "Walking past a betting shop on your way home",
                    "Thinking 'I have a system that can beat the odds'",
                    "A friend inviting you to poker night",
                ],
                correctIndex: 2
            )
        ),

        // Practice-only: house edge
        Question(
            id: "q-house-edge-why",
            moduleId: module.id,
            tags: ["house-edge", "probability"],
            difficulty: 1,
            prompt: "Why does the house always win in the long run?",
            explanation: "Every casino game has a built-in mathematical edge for the house. No strategy or streak can overcome this over time. The more you play, the more the house edge works against you.",
            payload: .multipleChoice(
                options: [
                    "Casinos cheat by rigging the machines",
                    "Every game has a built-in mathematical advantage for the house",
                    "Lucky streaks always end eventually",
                    "The house only wins because most people don't know the right strategies",
                ],
                correctIndex: 1
            )
        ),

        // Practice T/F: independence of spins
        Question(
            id: "q-spins-independent",
            moduleId: module.id,
            tags: ["gamblers-fallacy", "probability"],
            difficulty: 1,
            prompt: "Each spin on a slot machine is completely independent of all previous spins.",
            explanation: "Slot machines use random number generators. Each spin is a separate random event with no connection to past results. The machine has no memory.",
            payload: .trueFalse(answer: true)
        ),

        // Practice T/F: roulette streak (T/F variant)
        Question(
            id: "q-roulette-streak-tf",
            moduleId: module.id,
            tags: ["gamblers-fallacy", "probability"],
            difficulty: 1,
            prompt: "If a roulette wheel lands on red 10 times in a row, black is more likely on the next spin.",
            explanation: "This is the Gambler's Fallacy. Each spin of the roulette wheel is independent. The wheel has no memory. The probability of black is always about 47.4%, regardless of previous results.",
            payload: .trueFalse(answer: false)
        ),

        // Practice T/F: gambling frequency
        Question(
            id: "q-gambling-frequency",
            moduleId: module.id,
            tags: ["problem-gambling", "definition"],
            difficulty: 1,
            prompt: "Problem gambling only affects people who gamble every single day.",
            explanation: "Problem gambling can affect anyone regardless of frequency. Someone who bets once a week but loses rent money has a gambling problem. It's about impact, not just frequency.",
            payload: .trueFalse(answer: false)
        ),

        // Practice matching: trigger categories
        Question(
            id: "q-trigger-categories-match",
            moduleId: module.id,
            tags: ["triggers"],
            difficulty: 2,
            prompt: "Match each trigger type to its example:",
            explanation: "Recognizing which category a trigger belongs to helps you prepare targeted coping strategies for each type.",
            payload: .matching(pairs: [
                .init("Emotional", "Feeling lonely on a Friday night"),
                .init("Environmental", "Walking past a casino"),
                .init("Social", "Friends talking about their bets"),
                .init("Cognitive", "Thinking 'just one bet won't hurt'"),
            ])
        ),

        // Practice matching: house edge by game
        Question(
            id: "q-house-edge-match",
            moduleId: module.id,
            tags: ["house-edge", "probability"],
            difficulty: 2,
            prompt: "Match each game to its approximate house edge:",
            explanation: "Every casino game is designed to give the house an edge. The house edge means that over time, the casino always profits. The higher the edge, the faster you lose money.",
            payload: .matching(pairs: [
                .init("Slot machines", "2-15% edge"),
                .init("Roulette", "2.7-5.3% edge"),
                .init("Blackjack", "0.5-2% edge"),
                .init("Sports betting", "~5% vig"),
            ])
        ),

        // MultipleSelect: signs of problem gambling
        Question(
            id: "q-problem-gambling-signs-ms",
            moduleId: module.id,
            tags: ["problem-gambling", "warning-signs"],
            difficulty: 2,
            prompt: "Which of these are signs of problem gambling? Select all that apply.",
            explanation: "Problem gambling shows up as hidden behavior, chasing losses, and restlessness when trying to stop. Going to a friend's casino-themed birthday party isn't a sign of disorder, and an annual lottery ticket within budget is recreational, not problematic.",
            payload: .multipleSelect(
                options: [
                    "Lying to others about how much you gamble",
                    "Going to a friend's casino-themed birthday party",
                    "Borrowing money to keep gambling",
                    "Feeling restless when trying to stop",
                    "Buying a lottery ticket once a year",
                ],
                correctIndices: [0, 2, 3]
            )
        ),

        // MultipleSelect: which of these are common triggers
        Question(
            id: "q-trigger-types-ms",
            moduleId: module.id,
            tags: ["triggers"],
            difficulty: 2,
            prompt: "Which of these are common gambling triggers? Select all that apply.",
            explanation: "Stress, payday, advertising, and unstructured lonely time are classic gambling triggers. Eating dinner is usually neutral.",
            payload: .multipleSelect(
                options: [
                    "Receiving your paycheck",
                    "Eating dinner",
                    "Seeing a sports betting ad",
                    "Feeling lonely on a Friday night",
                    "Walking past a casino on your commute",
                ],
                correctIndices: [0, 2, 3, 4]
            )
        ),

        // FillInBlank freeType: define the Gambler's Fallacy
        Question(
            id: "q-fallacy-fillin",
            moduleId: module.id,
            tags: ["gamblers-fallacy", "probability"],
            difficulty: 2,
            prompt: "Fill in the missing words to define the Gambler's Fallacy.",
            explanation: "The Gambler's Fallacy is the mistaken belief that past random events affect future random events. Coins, dice, and slot machines have no memory.",
            payload: .fillInBlank(
                template: "The ___ Fallacy is the belief that past random events affect ___ random events.",
                acceptedAnswers: [
                    ["gambler's", "gamblers", "gambler"],
                    ["future"],
                ],
                mode: .freeType
            )
        ),

        // FillInBlank wordBank: house edge
        Question(
            id: "q-house-edge-fillin",
            moduleId: module.id,
            tags: ["house-edge", "probability"],
            difficulty: 1,
            prompt: "Tap the words to complete this fact about casinos.",
            explanation: "Casino games are deliberately designed with a built-in mathematical advantage for the house. Over time that advantage — the house edge — guarantees the casino profits.",
            payload: .fillInBlank(
                template: "Casino games are designed so the ___ always wins through a built-in ___ edge.",
                acceptedAnswers: [
                    ["house"],
                    ["mathematical"],
                ],
                mode: .wordBank(words: ["house", "mathematical", "player", "luck", "skill"])
            )
        ),

        // SortOrder: house edge from worst to best for the player
        Question(
            id: "q-house-edge-sort",
            moduleId: module.id,
            tags: ["house-edge", "probability"],
            difficulty: 3,
            prompt: "Order these games from highest house edge (worst player odds) to lowest.",
            explanation: "Slots have the worst player odds (2-15% edge), then sports betting (~5% vig), roulette (2.7-5.3%), and blackjack with basic strategy is the lowest of common casino games (~0.5-2%).",
            payload: .sortOrder(items: [
                "Slot machines",
                "Sports betting",
                "Roulette",
                "Blackjack",
            ])
        ),

        // SwipeCategorize: trigger or not
        Question(
            id: "q-trigger-swipe",
            moduleId: module.id,
            tags: ["triggers"],
            difficulty: 2,
            prompt: "Sort each card: is this commonly a gambling trigger?",
            explanation: "Triggers are anything that reliably increases the urge to gamble. Recovery isn't about eliminating every trigger — it's about recognizing them early so you can prepare a response.",
            payload: .swipeCategorize(
                leftLabel: "Not a trigger",
                rightLabel: "Trigger",
                cards: [
                    .init(text: "Watching a nature documentary", correctSide: .left),
                    .init(text: "Getting paid", correctSide: .right),
                    .init(text: "A sports betting commercial", correctSide: .right),
                    .init(text: "Cooking dinner with family", correctSide: .left),
                    .init(text: "Walking past a casino", correctSide: .right),
                    .init(text: "Feeling lonely at night", correctSide: .right),
                ]
            )
        ),
    ]
}
