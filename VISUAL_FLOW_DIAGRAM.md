# Group Score Feature - Visual Flow Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GROUP SCORE SYSTEM                          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐         ┌─────────────────┐
│  Admin/Frontend │         │   User/Member   │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │ Set Manual Score          │ Receives Individual Score
         │                           │
         ▼                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                         API GATEWAY                             │
└────┬─────────────────────────────────────────────────────┬──────┘
     │                                                      │
     │                                                      │
     ▼                                                      ▼
┌──────────────────────┐                        ┌──────────────────────┐
│   GROUP SERVICE      │                        │   SCORING SERVICE    │
│   (Port 5003)        │◄───────────────────────│   (Port 5004)        │
│                      │  Fetch manual_score    │                      │
│ ┌──────────────────┐ │  & group members       │ ┌──────────────────┐ │
│ │ Groups Table     │ │                        │ │ Scores Table     │ │
│ │ ┌──────────────┐ │ │                        │ │ ┌──────────────┐ │ │
│ │ │ id           │ │ │                        │ │ │ user_id      │ │ │
│ │ │ name         │ │ │                        │ │ │ group_id     │ │ │
│ │ │ manual_score │◄┼─┼────────────────────────┼─┼─│ score_value  │ │ │
│ │ │ ...          │ │ │                        │ │ │ category     │ │ │
│ │ └──────────────┘ │ │                        │ │ └──────────────┘ │ │
│ │                  │ │                        │ │                  │ │
│ │ Group Members    │ │                        │ │ Score Aggregates │ │
│ │ ┌──────────────┐ │ │                        │ │ ┌──────────────┐ │ │
│ │ │ group_id     │ │ │                        │ │ │ group_id     │ │ │
│ │ │ user_id      │◄┼─┼────────────────────────┼─┼─│ total_score  │ │ │
│ │ │ role         │ │ │                        │ │ │ category     │ │ │
│ │ └──────────────┘ │ │                        │ │ └──────────────┘ │ │
│ └──────────────────┘ │                        │ └──────────────────┘ │
└──────────────────────┘                        └──────────────────────┘
         │                                                      │
         │                                                      │
         ▼                                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATABASE (PostgreSQL)                      │
└─────────────────────────────────────────────────────────────────┘
```

## Score Calculation Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                   GROUP SCORE CALCULATION                        │
└──────────────────────────────────────────────────────────────────┘

Step 1: Fetch Group Manual Score
┌──────────────────────┐
│ Groups Table         │
│ manual_score: 100    │──────► Manual Score = 100
└──────────────────────┘

Step 2: Calculate Member Scores Sum
┌──────────────────────────────────────────────────────────┐
│ Group Members:                                           │
│  Member A (user_id: 123) → Scores Table → 30 points     │
│  Member B (user_id: 456) → Scores Table → 20 points     │
│  Member C (user_id: 789) → Scores Table → 10 points     │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼
                Member Scores Sum = 60

Step 3: Fetch Direct Group Scores
┌──────────────────────┐
│ Scores Table         │
│ group_id: group-123  │
│ score_value: 15      │──────► Direct Scores = 15
└──────────────────────┘

Step 4: Calculate Total
┌────────────────────────────────────────────────────┐
│  Total Group Score = Manual + Members + Direct     │
│                                                    │
│  Total = 100 + 60 + 15 = 175                      │
└────────────────────────────────────────────────────┘

Step 5: Update Aggregate
┌──────────────────────┐
│ Score Aggregates     │
│ group_id: group-123  │
│ total_score: 175     │──────► Stored for Leaderboard
└──────────────────────┘
```

## API Call Sequence Diagram

```
Admin                 API Gateway        Group Service      Scoring Service      Database
  │                        │                    │                   │                │
  │ 1. Set Manual Score    │                    │                   │                │
  ├────────────────────────►                    │                   │                │
  │                        │ PUT /groups/{id}   │                   │                │
  │                        │    /manual-score   │                   │                │
  │                        ├────────────────────►                   │                │
  │                        │                    │ UPDATE groups     │                │
  │                        │                    ├───────────────────────────────────►│
  │                        │                    │                   │                │
  │                        │                    │◄──────────────────────────────────┤│
  │                        │      Success       │                   │                │
  │                        │◄───────────────────┤                   │                │
  │        200 OK          │                    │                   │                │
  │◄───────────────────────┤                    │                   │                │
  │                        │                    │                   │                │
  │                        │                    │                   │                │
User                      │                    │                   │                │
  │                        │                    │                   │                │
  │ 2. Assign Score        │                    │                   │                │
  │    to Member           │                    │                   │                │
  ├────────────────────────►                    │                   │                │
  │                        │ POST /scores       │                   │                │
  │                        ├────────────────────────────────────────►                │
  │                        │                    │                   │ INSERT score   │
  │                        │                    │                   ├───────────────►│
  │                        │                    │                   │                │
  │                        │                    │                   │ Calculate      │
  │                        │                    │ Get manual_score  │ Aggregate      │
  │                        │                    │◄──────────────────┤                │
  │                        │                    ├───────────────────►                │
  │                        │                    │                   │                │
  │                        │                    │ Get members       │                │
  │                        │                    │◄──────────────────┤                │
  │                        │                    ├───────────────────►                │
  │                        │                    │                   │                │
  │                        │                    │                   │ Sum member     │
  │                        │                    │                   │ scores         │
  │                        │                    │                   ├───────────────►│
  │                        │                    │                   │◄───────────────┤│
  │                        │                    │                   │                │
  │                        │                    │                   │ Update         │
  │                        │                    │                   │ aggregate      │
  │                        │                    │                   ├───────────────►│
  │                        │      Success       │                   │                │
  │                        │◄───────────────────────────────────────┤                │
  │        201 Created     │                    │                   │                │
  │◄───────────────────────┤                    │                   │                │
  │                        │                    │                   │                │
```

## Data Flow for Score Breakdown

```
┌─────────────────────────────────────────────────────────────────────┐
│  GET /scores/group/{id}/total?category=general                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────┐
         │  Scoring Service - get_group_      │
         │  total_score() function            │
         └────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────┐
         │ 1. Get Direct Group Scores         │
         │    Query: scores WHERE group_id    │
         │    Result: 15                      │
         └────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────┐
         │ 2. Get Manual Score                │
         │    Call: get_group_manual_score()  │
         │    HTTP: GET /groups/{id}          │
         │    Result: 100                     │
         └────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────┐
         │ 3. Calculate Members Score Sum     │
         │    Call: calculate_group_members_  │
         │          score_sum()               │
         │    - Get members from group-service│
         │    - Sum their scores from DB      │
         │    Result: 60                      │
         └────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────┐
         │ 4. Calculate Total                 │
         │    Total = 15 + 100 + 60 = 175    │
         └────────────────────────────────────┘
                              │
                              ▼
         ┌────────────────────────────────────┐
         │ 5. Return Breakdown                │
         │    {                               │
         │      "total_score": 175,           │
         │      "breakdown": {                │
         │        "direct_group_scores": 15,  │
         │        "manual_score": 100,        │
         │        "members_score_sum": 60     │
         │      }                             │
         │    }                               │
         └────────────────────────────────────┘
```

## Leaderboard Update Flow

```
When Member Score Changes:
┌─────────────────────────────────────────────────────────────┐
│ 1. Score assigned to Member A                               │
│    POST /scores { user_id: "member-A", score_value: 30 }   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. update_score_aggregate() triggered                       │
│    - Updates user aggregate (Member A's personal total)     │
│    - Updates group aggregate (Group's total)                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Group Aggregate Recalculated                             │
│    - Manual score: fetched from groups table                │
│    - Member scores: summed from all member individual scores│
│    - Direct scores: group-specific scores                   │
│    - Total: All three combined                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Leaderboard Automatically Updated                        │
│    - Reads from score_aggregates table                      │
│    - Displays new total with updated ranking                │
└─────────────────────────────────────────────────────────────┘
```

## Key Relationships

```
┌────────────┐         ┌─────────────┐         ┌──────────┐
│   Groups   │────1────┼──────M──────┤  Group  │  Users   │
│            │         │   Members   │         │          │
│ • id       │         │             │         │ • id     │
│ • name     │         │ • group_id  │         │ • name   │
│ • manual_  │         │ • user_id   │         │          │
│   score    │         │             │         │          │
└────────────┘         └─────────────┘         └──────────┘
      │                      │                       │
      │                      │                       │
      └──────────────────────┴───────────────────────┘
                             │
                             ▼
                      ┌──────────┐
                      │  Scores  │
                      │          │
                      │ • user_id│
                      │ • group  │
                      │   _id    │
                      │ • score  │
                      │   _value │
                      └──────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │ Score Aggregates │
                   │                  │
                   │ • total_score    │
                   │ • category       │
                   └──────────────────┘
```

---

This visual guide helps understand how the manual score feature integrates with the existing scoring system and how data flows through the different services!
