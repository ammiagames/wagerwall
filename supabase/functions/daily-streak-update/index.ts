// daily-streak-update/index.ts
// Runs daily at midnight to update streaks and money saved estimates.
// Triggered by pg_cron daily.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.includes(serviceRoleKey)) {
      return new Response("Unauthorized", { status: 401 });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Fetch all streaks with their user profiles
    const { data: streaks, error: streakError } = await supabase
      .from("user_streaks")
      .select("id, user_id, current_streak_days, longest_streak_days, last_check_in");

    if (streakError) throw streakError;
    if (!streaks || streaks.length === 0) {
      return new Response(
        JSON.stringify({ message: "No streaks to update" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
    const yesterday = new Date(Date.now() - 86400000)
      .toISOString()
      .split("T")[0];

    let updated = 0;
    let milestones = 0;

    for (const streak of streaks) {
      const lastCheckIn = streak.last_check_in;

      if (lastCheckIn === today || lastCheckIn === yesterday) {
        // User checked in today or yesterday — increment streak
        const newStreakDays = lastCheckIn === today
          ? streak.current_streak_days
          : streak.current_streak_days; // Don't auto-increment, user must check in

        // Update money saved estimate
        const { data: profile } = await supabase
          .from("user_profiles")
          .select("quit_date, daily_gambling_spend")
          .eq("id", streak.user_id)
          .single();

        if (profile?.quit_date && profile?.daily_gambling_spend) {
          const quitDate = new Date(profile.quit_date);
          const daysSinceQuit = Math.max(
            0,
            Math.floor(
              (Date.now() - quitDate.getTime()) / (1000 * 60 * 60 * 24),
            ),
          );
          const moneySaved = daysSinceQuit * profile.daily_gambling_spend;

          await supabase
            .from("user_streaks")
            .update({
              money_saved_estimate: moneySaved,
              longest_streak_days: Math.max(
                streak.longest_streak_days,
                newStreakDays,
              ),
            })
            .eq("id", streak.id);

          updated++;
        }

        // Check for milestones (7, 30, 90, 180, 365 days)
        const milestonesDays = [7, 30, 90, 180, 365];
        if (milestonesDays.includes(newStreakDays)) {
          milestones++;

          // Notify the user about their milestone
          try {
            await supabase.functions.invoke("send-push", {
              body: {
                userId: streak.user_id,
                title: "Milestone Reached!",
                body: `Incredible! You've reached ${newStreakDays} days gambling-free!`,
                data: { type: "streak_milestone", days: String(newStreakDays) },
              },
            });
          } catch {
            // Non-critical
          }

          // Notify partner about milestone
          const { data: partners } = await supabase
            .from("accountability_partners")
            .select("partner_email, partner_user_id")
            .eq("user_id", streak.user_id)
            .eq("status", "active");

          if (partners) {
            for (const partner of partners) {
              try {
                await supabase.functions.invoke("notify-partner", {
                  body: {
                    userId: streak.user_id,
                    partnerEmail: partner.partner_email,
                    partnerUserId: partner.partner_user_id,
                    type: "streak_milestone",
                    message: `reached ${newStreakDays} days gambling-free!`,
                  },
                });
              } catch {
                // Non-critical
              }
            }
          }
        }
      } else {
        // User hasn't checked in for more than a day — reset streak
        if (streak.current_streak_days > 0) {
          await supabase
            .from("user_streaks")
            .update({ current_streak_days: 0 })
            .eq("id", streak.id);
          updated++;
        }
      }
    }

    return new Response(
      JSON.stringify({
        message: `Updated ${updated} streaks, ${milestones} milestones triggered`,
        total: streaks.length,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
