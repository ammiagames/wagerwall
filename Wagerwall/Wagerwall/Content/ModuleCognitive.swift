import Foundation

/// Module 2: Cognitive Restructuring.
/// Identify and challenge the thinking patterns that fuel gambling behavior.
enum ModuleCognitive {

    static let module = Module(
        id: "module-cognitive",
        title: "Cognitive Restructuring",
        description: "Identify and challenge the thinking patterns that fuel gambling behavior.",
        sortOrder: 2,
        estimatedMinutes: 35,
        iconName: "lightbulb.fill"
    )

    // MARK: - Lessons

    static let lessons: [Lesson] = [
        lessonThinkingTraps,
        lessonChallengingThoughts,
        lessonHealthierBeliefs,
    ]

    private static let lessonThinkingTraps = Lesson(
        id: "lesson-thinking-traps",
        moduleId: module.id,
        title: "Thinking Traps",
        description: "Learn to spot the cognitive distortions that keep you gambling.",
        sortOrder: 1,
        estimatedMinutes: 12,
        sections: [
            .text(title: "What Are Thinking Traps?", body: """
            Thinking traps (also called cognitive distortions) are habitual ways of thinking that are biased or inaccurate. Everyone has them, but people with gambling problems tend to have specific thinking traps that make gambling seem more appealing or rational than it actually is.

            These aren't signs of low intelligence — they're deeply wired patterns in how human brains process information about probability, risk, and reward.
            """),
            .text(title: "Common Gambling Thinking Traps", body: """
            **Illusion of Control**: Believing you can influence random outcomes through skill, rituals, or strategies. ("I always pick winning numbers when I feel lucky.")

            **Selective Memory**: Remembering wins vividly while forgetting or minimizing losses. ("I won $500 last month!" — while ignoring $2,000 in losses.)

            **Near-Miss Effect**: Treating almost-winning as evidence you're close to winning. ("I was so close! One more try...")

            **Chasing**: Believing you must keep gambling to recover losses. ("I'm down $200, I need one good bet to get back to even.")

            **Superstitious Thinking**: Believing in lucky charms, rituals, or timing. ("I always win when I wear this shirt.")
            """),
            .callout(style: .tip, body: "The first step to defeating a thinking trap is noticing when you're in one. Practice labeling the trap: \"That's the near-miss effect talking\" or \"I'm selectively remembering my wins.\""),
            .question("q-near-miss-identify"),
            .journal(prompt: "Think about the last few times you gambled. Can you identify which thinking traps were active? Write about one specific example and which trap(s) were involved."),
        ]
    )

    private static let lessonChallengingThoughts = Lesson(
        id: "lesson-challenging-thoughts",
        moduleId: module.id,
        title: "Challenging Distorted Thoughts",
        description: "Learn practical techniques to question and reframe gambling-related thoughts.",
        sortOrder: 2,
        estimatedMinutes: 12,
        sections: [
            .text(title: "The Thought Record", body: """
            A thought record is a CBT tool that helps you examine and challenge distorted thinking. It works in four steps:

            1. **Situation**: What triggered the gambling urge?
            2. **Automatic Thought**: What went through your mind?
            3. **Thinking Trap**: Which distortion is at work?
            4. **Balanced Thought**: What's a more realistic way to see this?
            """),
            .callout(style: .example, body: """
            Situation: I got my paycheck and thought about the casino.

            Automatic thought: "I could double my paycheck tonight if I play smart."

            Thinking trap: Illusion of Control

            Balanced thought: "The odds are against me. Every time I've tried to 'play smart' I've lost money. My paycheck is worth more in my savings account."
            """),
            .text(title: "Questions to Challenge Your Thoughts", body: """
            When you notice a gambling-related thought, ask yourself:

            • What evidence supports this thought? What evidence contradicts it?
            • Am I confusing a feeling with a fact?
            • What would I say to a friend who had this thought?
            • What's the most realistic outcome, not the best-case scenario?
            • Have I been in this situation before? What actually happened?
            • Am I thinking in all-or-nothing terms?
            """),
            .question("q-challenge-lucky-feeling"),
            .journal(prompt: "Write a thought record for a recent gambling urge. Include the situation, your automatic thought, the thinking trap involved, and a more balanced alternative thought."),
        ]
    )

    private static let lessonHealthierBeliefs = Lesson(
        id: "lesson-healthier-beliefs",
        moduleId: module.id,
        title: "Building Healthier Beliefs",
        description: "Replace gambling-supportive beliefs with recovery-supportive ones.",
        sortOrder: 3,
        estimatedMinutes: 11,
        sections: [
            .text(title: "Core Beliefs and Gambling", body: """
            Underneath our automatic thoughts are deeper core beliefs. These are fundamental assumptions we hold about ourselves, others, and the world.

            People with gambling problems often hold beliefs like:
            • "I'm not capable of earning enough money legitimately"
            • "I deserve the excitement gambling gives me"
            • "Life is boring without risk"
            • "Money is the key to happiness"
            • "I'm a lucky person"

            These beliefs weren't formed overnight, and they won't change overnight. But you can start building new, healthier beliefs with practice.
            """),
            .text(title: "Recovery-Supportive Beliefs", body: """
            Here are beliefs that support recovery:

            • "I can find excitement and fulfillment in things that don't cost me everything"
            • "My worth isn't determined by my net worth"
            • "I am strong enough to sit with discomfort without gambling"
            • "Slow, steady financial progress is real — gambling wins are an illusion"
            • "I deserve a life free from the anxiety and shame that gambling causes"
            """),
            .callout(style: .reflection, body: "You don't have to believe the new belief 100% right away. Start by being willing to consider it. Over time and with evidence, new beliefs become stronger."),
            .question("q-changing-beliefs"),
            .journal(prompt: "Choose one gambling-supportive belief you hold and write a recovery-supportive alternative. Then list 2-3 pieces of evidence from your own life that support the healthier belief."),
        ]
    )

    // MARK: - Questions

    static let questions: [Question] = [
        // Lesson 2.1 quiz + practice
        Question(
            id: "q-near-miss-identify",
            moduleId: module.id,
            tags: ["cognitive-distortions", "near-miss"],
            difficulty: 1,
            prompt: "You're playing a slot machine and get two out of three matching symbols. You think: 'I was so close! I should keep playing.' Which thinking trap is this?",
            explanation: "This is the Near-Miss Effect. Slot machines are specifically designed to show near-misses frequently because they encourage continued play. In reality, a near-miss is no closer to winning than any other losing combination.",
            payload: .multipleChoice(
                options: [
                    "Illusion of Control",
                    "Selective Memory",
                    "Near-Miss Effect",
                    "Superstitious Thinking",
                ],
                correctIndex: 2
            )
        ),

        // Lesson 2.2 quiz + practice
        Question(
            id: "q-challenge-lucky-feeling",
            moduleId: module.id,
            tags: ["thought-record", "challenging-thoughts"],
            difficulty: 2,
            prompt: "You think: 'I just have a feeling tonight is my lucky night.' Which question would BEST help challenge this thought?",
            explanation: "Asking about realistic outcomes based on past experience challenges the 'lucky feeling' by grounding you in facts. Most people who act on lucky feelings end up losing money.",
            payload: .multipleChoice(
                options: [
                    "What's the most realistic outcome based on past experience?",
                    "How much money should I bring?",
                    "Which game should I play?",
                    "What time should I go?",
                ],
                correctIndex: 0
            )
        ),

        // Lesson 2.3 quiz + practice
        Question(
            id: "q-changing-beliefs",
            moduleId: module.id,
            tags: ["beliefs", "recovery"],
            difficulty: 2,
            prompt: "What is the best way to change a deeply held belief?",
            explanation: "Beliefs change through accumulated evidence and experience, not through willpower alone. Each day you don't gamble, each time you cope with an urge, you're gathering evidence for your new recovery-supportive beliefs.",
            payload: .multipleChoice(
                options: [
                    "Just decide to believe something different",
                    "Gradually gather evidence that supports the new belief through experience",
                    "Ignore the old belief completely",
                    "Wait until you feel ready to change",
                ],
                correctIndex: 1
            )
        ),

        // Practice T/F: near-miss
        Question(
            id: "q-near-miss-tf",
            moduleId: module.id,
            tags: ["cognitive-distortions", "near-miss"],
            difficulty: 1,
            prompt: "Getting 'close to winning' on a slot machine means you are more likely to win soon.",
            explanation: "This is the Near-Miss Effect. Slot machines are programmed to show near-misses frequently because it keeps players engaged. Each spin is independent — a near-miss has no bearing on future outcomes.",
            payload: .trueFalse(answer: false)
        ),

        // Practice T/F: thought record steps
        Question(
            id: "q-thought-record-steps",
            moduleId: module.id,
            tags: ["thought-record", "challenging-thoughts"],
            difficulty: 1,
            prompt: "A thought record involves four steps: Situation, Automatic Thought, Thinking Trap, and Balanced Thought.",
            explanation: "The thought record is a core CBT tool. By writing down the situation, your automatic thought, identifying the distortion, and creating a balanced alternative, you can break the cycle of distorted thinking.",
            payload: .trueFalse(answer: true)
        ),

        // Practice T/F: belief change immediacy
        Question(
            id: "q-belief-change-immediate",
            moduleId: module.id,
            tags: ["beliefs", "recovery"],
            difficulty: 1,
            prompt: "You need to believe a new recovery-supportive thought 100% right away for it to be helpful.",
            explanation: "You don't need to fully believe a new thought immediately. Start by being willing to consider it. Over time, as you gather evidence through experience, new beliefs naturally become stronger.",
            payload: .trueFalse(answer: false)
        ),

        // Practice matching: thinking traps
        Question(
            id: "q-thinking-traps-match",
            moduleId: module.id,
            tags: ["cognitive-distortions"],
            difficulty: 2,
            prompt: "Match each thinking trap to its description:",
            explanation: "Learning to name these thinking traps is the first step to defeating them. When you notice one, try labeling it: 'That's selective memory talking.'",
            payload: .matching(pairs: [
                .init("Gambler's Fallacy", "Past results predict future outcomes"),
                .init("Illusion of Control", "Skill can influence random events"),
                .init("Selective Memory", "Remembering wins, forgetting losses"),
                .init("Chasing Losses", "Gambling more to recover money"),
            ])
        ),

        // Practice matching: distorted to balanced
        Question(
            id: "q-distorted-balanced-match",
            moduleId: module.id,
            tags: ["challenging-thoughts"],
            difficulty: 3,
            prompt: "Match each distorted thought to a balanced alternative:",
            explanation: "Balanced thoughts aren't blindly positive — they're realistic. They acknowledge difficulty while reflecting the full picture, not just the gambling-distorted version.",
            payload: .matching(pairs: [
                .init("I could double my money tonight", "The odds are against me every time"),
                .init("I'm due for a win", "Each bet is independent of the last"),
                .init("One bet won't hurt", "One bet has led to binges before"),
                .init("Gambling is my only excitement", "I can find excitement in healthier ways"),
            ])
        ),

        // MultipleSelect: which are gambling thinking traps
        Question(
            id: "q-distortions-ms",
            moduleId: module.id,
            tags: ["cognitive-distortions"],
            difficulty: 2,
            prompt: "Which of these are gambling thinking traps? Select all that apply.",
            explanation: "Selective memory, illusion of control, and chasing losses are all classic cognitive distortions in problem gambling. Patience and curiosity are healthy thinking habits, not distortions.",
            payload: .multipleSelect(
                options: [
                    "Selective memory (remembering wins, forgetting losses)",
                    "Patience (waiting for the right moment)",
                    "Illusion of control (skill can influence randomness)",
                    "Chasing losses (gambling more to recover)",
                    "Curiosity (asking questions)",
                ],
                correctIndices: [0, 2, 3]
            )
        ),

        // MultipleSelect: thought-record steps
        Question(
            id: "q-thought-record-ms",
            moduleId: module.id,
            tags: ["thought-record", "challenging-thoughts"],
            difficulty: 2,
            prompt: "A thought record includes which steps? Select all that apply.",
            explanation: "The four steps of a thought record are situation, automatic thought, thinking trap, and balanced thought. Doubling your bet to test a prediction or consulting astrology are not part of CBT — they're extensions of the distortion.",
            payload: .multipleSelect(
                options: [
                    "Identify the situation that triggered the thought",
                    "Double your bet to test the prediction",
                    "Notice the automatic thought",
                    "Identify which thinking trap is at work",
                    "Write a balanced alternative thought",
                ],
                correctIndices: [0, 2, 3, 4]
            )
        ),

        // FillInBlank wordBank: thought-record skeleton
        Question(
            id: "q-thought-record-fillin",
            moduleId: module.id,
            tags: ["thought-record"],
            difficulty: 1,
            prompt: "Tap the words to complete the four steps of a thought record.",
            explanation: "Situation → Automatic thought → Thinking trap → Balanced thought. This sequence is the heart of CBT for cognitive distortions.",
            payload: .fillInBlank(
                template: "Situation, ___ thought, ___ trap, balanced thought.",
                acceptedAnswers: [
                    ["automatic"],
                    ["thinking"],
                ],
                mode: .wordBank(words: ["automatic", "thinking", "lucky", "winning", "balanced"])
            )
        ),

        // FillInBlank freeType: near-miss
        Question(
            id: "q-near-miss-fillin",
            moduleId: module.id,
            tags: ["near-miss", "cognitive-distortions"],
            difficulty: 2,
            prompt: "Complete the sentence about a key cognitive distortion.",
            explanation: "Slot machines are deliberately programmed to show frequent near-misses because they exploit the brain's tendency to treat 'almost winning' as evidence you're close. Statistically, a near-miss is no closer to a win than any other loss.",
            payload: .fillInBlank(
                template: "The ___-miss effect makes you feel close to winning when you're actually not.",
                acceptedAnswers: [["near"]],
                mode: .freeType
            )
        ),

        // SortOrder: thought-record sequence
        Question(
            id: "q-thought-record-sort",
            moduleId: module.id,
            tags: ["thought-record", "challenging-thoughts"],
            difficulty: 2,
            prompt: "Put the four thought-record steps in the right order.",
            explanation: "You start with the situation, notice the automatic thought, identify the thinking trap, then craft a balanced alternative. Skipping steps leaves the distortion unchallenged.",
            payload: .sortOrder(items: [
                "Situation",
                "Automatic thought",
                "Thinking trap",
                "Balanced thought",
            ])
        ),

        // SwipeCategorize: distorted vs. balanced thoughts
        Question(
            id: "q-distorted-balanced-swipe",
            moduleId: module.id,
            tags: ["challenging-thoughts"],
            difficulty: 3,
            prompt: "Sort each thought: is it distorted, or already balanced?",
            explanation: "Distorted thoughts treat hopes and feelings as facts. Balanced thoughts acknowledge real evidence — including the wins AND the losses, the past patterns AND the underlying math.",
            payload: .swipeCategorize(
                leftLabel: "Distorted",
                rightLabel: "Balanced",
                cards: [
                    .init(text: "I'm due for a win", correctSide: .left),
                    .init(text: "Each spin is independent of the last", correctSide: .right),
                    .init(text: "I have a system that beats the odds", correctSide: .left),
                    .init(text: "The house has a built-in edge over time", correctSide: .right),
                    .init(text: "I always win when I wear my lucky shirt", correctSide: .left),
                    .init(text: "My past wins were lucky, not skill", correctSide: .right),
                ]
            )
        ),
    ]
}
