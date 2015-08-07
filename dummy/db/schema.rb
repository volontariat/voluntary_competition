# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150206162947) do

  create_table "areas", force: true do |t|
    t.string   "ancestry"
    t.integer  "ancestry_depth", default: 0
    t.integer  "position"
    t.string   "name"
    t.string   "slug"
    t.integer  "users_count",    default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "areas", ["ancestry"], name: "index_areas_on_ancestry", using: :btree
  add_index "areas", ["name"], name: "index_areas_on_name", unique: true, using: :btree
  add_index "areas", ["slug"], name: "index_areas_on_slug", unique: true, using: :btree

  create_table "areas_projects", force: true do |t|
    t.integer "area_id"
    t.integer "project_id"
  end

  add_index "areas_projects", ["area_id", "project_id"], name: "index_areas_projects_on_area_id_and_project_id", unique: true, using: :btree
  add_index "areas_projects", ["area_id"], name: "index_areas_projects_on_area_id", using: :btree
  add_index "areas_projects", ["project_id"], name: "index_areas_projects_on_project_id", using: :btree

  create_table "areas_users", force: true do |t|
    t.integer "area_id"
    t.integer "user_id"
  end

  add_index "areas_users", ["area_id", "user_id"], name: "index_areas_users_on_area_id_and_user_id", unique: true, using: :btree
  add_index "areas_users", ["area_id"], name: "index_areas_users_on_area_id", using: :btree
  add_index "areas_users", ["user_id"], name: "index_areas_users_on_user_id", using: :btree

  create_table "candidatures", force: true do |t|
    t.integer  "vacancy_id"
    t.integer  "offeror_id"
    t.string   "name"
    t.string   "slug"
    t.text     "text"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "resource_type"
    t.integer  "resource_id"
  end

  add_index "candidatures", ["resource_id", "resource_type", "vacancy_id"], name: "index_candidatures_on_resource_and_vacancy", unique: true, using: :btree
  add_index "candidatures", ["slug"], name: "index_candidatures_on_slug", unique: true, using: :btree
  add_index "candidatures", ["vacancy_id", "name"], name: "index_candidatures_on_vacancy_id_and_name", unique: true, using: :btree
  add_index "candidatures", ["vacancy_id"], name: "index_candidatures_on_vacancy_id", using: :btree

  create_table "comments", force: true do |t|
    t.string   "commentable_type"
    t.integer  "commentable_id"
    t.integer  "user_id"
    t.string   "ancestry"
    t.integer  "ancestry_depth",   default: 0
    t.integer  "position"
    t.string   "name"
    t.text     "text"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comments", ["ancestry"], name: "index_comments_on_ancestry", using: :btree
  add_index "comments", ["commentable_id", "commentable_type"], name: "index_comments_on_commentable_id_and_commentable_type", using: :btree

  create_table "competitors", force: true do |t|
    t.string   "name"
    t.integer  "game_and_exercise_type_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "competitors", ["user_id", "game_and_exercise_type_id", "name"], name: "unique_competitor_index", unique: true, using: :btree

  create_table "exercise_types", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "exercise_types", ["name"], name: "name", unique: true, using: :btree

  create_table "friendly_id_slugs", force: true do |t|
    t.string   "slug",                      null: false
    t.integer  "sluggable_id",              null: false
    t.string   "sluggable_type", limit: 40
    t.datetime "created_at"
  end

  add_index "friendly_id_slugs", ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type", unique: true, using: :btree
  add_index "friendly_id_slugs", ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id", using: :btree
  add_index "friendly_id_slugs", ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type", using: :btree

  create_table "game_and_exercise_types", force: true do |t|
    t.integer  "game_id"
    t.integer  "exercise_type_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "game_and_exercise_types", ["exercise_type_id"], name: "index_game_and_exercise_types_on_exercise_type_id", using: :btree
  add_index "game_and_exercise_types", ["game_id", "exercise_type_id"], name: "index_game_and_exercise_types_on_game_id_and_exercise_type_id", unique: true, using: :btree

  create_table "games", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "games", ["name"], name: "index_games_on_name", unique: true, using: :btree

  create_table "likes", force: true do |t|
    t.boolean  "positive",               default: true
    t.integer  "target_id"
    t.string   "target_type", limit: 60,                null: false
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "likes", ["target_id", "user_id", "target_type"], name: "index_likes_on_target_id_and_user_id_and_target_type", unique: true, using: :btree

  create_table "list_items", force: true do |t|
    t.integer  "list_id"
    t.integer  "user_id"
    t.string   "thing_type"
    t.integer  "thing_id"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "lists", force: true do |t|
    t.integer  "user_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "lists", ["user_id"], name: "index_lists_on_user_id", using: :btree

  create_table "mongo_db_documents", force: true do |t|
    t.string   "mongo_db_object_id"
    t.string   "klass_name"
    t.string   "name"
    t.string   "slug"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "mongo_db_documents", ["mongo_db_object_id", "klass_name"], name: "index_mongo_db_documents_on_mongo_db_object_id_and_klass_name", unique: true, using: :btree

  create_table "organizations", force: true do |t|
    t.string   "name"
    t.string   "slug"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  add_index "organizations", ["slug"], name: "index_organizations_on_slug", using: :btree

  create_table "professions", force: true do |t|
    t.string   "name"
    t.string   "slug"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "projects", force: true do |t|
    t.integer  "user_id"
    t.string   "name"
    t.string   "slug"
    t.text     "text"
    t.string   "url"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "product_id"
    t.integer  "organization_id"
  end

  add_index "projects", ["organization_id"], name: "index_projects_on_organization_id", using: :btree
  add_index "projects", ["product_id"], name: "index_projects_on_product_id", using: :btree
  add_index "projects", ["slug"], name: "index_projects_on_slug", unique: true, using: :btree
  add_index "projects", ["user_id"], name: "index_projects_on_user_id", using: :btree

  create_table "projects_users", force: true do |t|
    t.integer "project_id"
    t.integer "vacancy_id"
    t.integer "role_id"
    t.integer "user_id"
    t.string  "state"
  end

  add_index "projects_users", ["project_id", "user_id", "vacancy_id"], name: "index_projects_users_on_project_id_and_user_id_and_vacancy_id", unique: true, using: :btree
  add_index "projects_users", ["project_id"], name: "index_projects_users_on_project_id", using: :btree
  add_index "projects_users", ["role_id"], name: "index_projects_users_on_role_id", using: :btree
  add_index "projects_users", ["user_id"], name: "index_projects_users_on_user_id", using: :btree
  add_index "projects_users", ["vacancy_id"], name: "index_projects_users_on_vacancy_id", using: :btree

  create_table "roles", force: true do |t|
    t.string   "name"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "public",     default: false
    t.string   "type"
  end

  create_table "things", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "things", ["name"], name: "index_things_on_name", unique: true, using: :btree

  create_table "tournament_matches", force: true do |t|
    t.integer  "season_id"
    t.integer  "group_number", limit: 2
    t.integer  "home_competitor_id"
    t.integer  "away_competitor_id"
    t.integer  "home_goals"
    t.integer  "away_goals"
    t.integer  "winner_competitor_id"
    t.integer  "loser_competitor_id"
    t.boolean  "draw"
    t.datetime "date"
    t.string   "state"
    t.integer  "matchday"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "round",                limit: 2
  end

  add_index "tournament_matches", ["season_id", "group_number", "matchday"], name: "tournament_matches_index", using: :btree
  
  create_table "tournament_season_participations", force: true do |t|
    t.integer  "season_id"
    t.integer  "competitor_id"
    t.integer  "user_id"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tournament_season_participations", ["season_id", "competitor_id"], name: "uniq_tournament_season_participation", unique: true, using: :btree

  create_table "tournament_season_rankings", force: true do |t|
    t.integer  "season_id"
    t.integer  "group_number", limit: 2
    t.integer  "matchday"
    t.boolean  "played",                      default: false
    t.integer  "position"
    t.integer  "previous_position"
    t.integer  "trend",             limit: 1, default: 0
    t.integer  "competitor_id"
    t.integer  "points",                      default: 0
    t.integer  "wins",                        default: 0
    t.integer  "draws",                       default: 0
    t.integer  "losses",                      default: 0
    t.integer  "goal_differential",           default: 0
    t.integer  "goals_scored",                default: 0
    t.integer  "goals_allowed",               default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "matches",                     default: 0
  end

  add_index "tournament_season_rankings", ["season_id", "group_number", "matchday", "position", "competitor_id"], name: "uniq_tournament_ranking", unique: true, using: :btree

  create_table "tournament_seasons", force: true do |t|
    t.integer  "tournament_id"
    t.string   "name"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "current_matchday"
    t.integer  "matchdays",        limit: 2
    t.boolean  "w_of_l_won_grand_finals_first_match_against_w_of_w"
  end

  add_index "tournament_seasons", ["tournament_id", "state"], name: "index_tournament_seasons_on_tournament_id_and_state", using: :btree

  create_table "tournaments", force: true do |t|
    t.string   "name"
    t.integer  "competitors_limit",         limit: 3
    t.integer  "current_season_id"
    t.integer  "game_and_exercise_type_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "matchdays_per_season"
    t.boolean  "with_second_leg",                     default: false
    t.integer  "system_type",               limit: 2, default: 0
    t.boolean  "third_place_playoff",                 default: false
    t.boolean  "with_group_stage",                    default: false
    t.integer  "groups_count", limit: 2
  end

  add_index "tournaments", ["user_id", "game_and_exercise_type_id", "name"], name: "unique_tournament_index", unique: true, using: :btree

  create_table "users", force: true do |t|
    t.string   "name"
    t.string   "slug"
    t.string   "rpx_identifier"
    t.string   "password"
    t.text     "text"
    t.text     "serialized_private_key"
    t.string   "language"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "salutation"
    t.string   "marital_status"
    t.string   "family_status"
    t.date     "date_of_birth"
    t.string   "place_of_birth"
    t.string   "citizenship"
    t.string   "email",                   default: ""
    t.string   "encrypted_password",      default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",           default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",         default: 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.string   "authentication_token"
    t.string   "password_salt"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "country"
    t.string   "interface_language"
    t.string   "employment_relationship"
    t.integer  "profession_id"
    t.integer  "main_role_id"
    t.text     "foreign_languages"
    t.string   "provider"
    t.string   "uid"
    t.string   "lastfm_user_name"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["name"], name: "index_users_on_name", unique: true, using: :btree
  add_index "users", ["profession_id"], name: "index_users_on_profession_id", using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["slug"], name: "index_users_on_slug", unique: true, using: :btree

  create_table "users_roles", force: true do |t|
    t.integer "role_id"
    t.integer "user_id"
    t.string  "state"
  end

  add_index "users_roles", ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id", unique: true, using: :btree

  create_table "vacancies", force: true do |t|
    t.string   "type"
    t.integer  "project_id"
    t.integer  "offeror_id"
    t.integer  "author_id"
    t.integer  "project_user_id"
    t.string   "name"
    t.string   "slug"
    t.text     "text"
    t.integer  "limit",           default: 1
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "resource_type"
    t.integer  "resource_id"
  end

  add_index "vacancies", ["offeror_id"], name: "index_vacancies_on_offeror_id", using: :btree
  add_index "vacancies", ["project_id", "name"], name: "index_vacancies_on_project_id_and_name", unique: true, using: :btree
  add_index "vacancies", ["project_id"], name: "index_vacancies_on_project_id", using: :btree
  add_index "vacancies", ["project_user_id"], name: "index_vacancies_on_project_user_id", using: :btree
  add_index "vacancies", ["slug"], name: "index_vacancies_on_slug", unique: true, using: :btree

end
