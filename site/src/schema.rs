table! {
    apps (id) {
        id -> Int4,
        app_name -> Text,
        domain -> Varchar,
        environment -> Varchar,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

table! {
    routes (id) {
        id -> Int4,
        app_id -> Int4,
        view_id -> Int4,
        route_name -> Nullable<Text>,
        pattern -> Varchar,
        pattern_regex -> Varchar,
        method_get -> Bool,
        method_post -> Bool,
        extra_methods -> Nullable<Array<Text>>,
    }
}

table! {
    views (id) {
        id -> Int4,
        app_id -> Int4,
        view_name -> Nullable<Text>,
        mime_type -> Varchar,
        asset_url -> Nullable<Text>,
        content -> Nullable<Text>,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

joinable!(routes -> apps (app_id));
joinable!(routes -> views (view_id));
joinable!(views -> apps (app_id));

allow_tables_to_appear_in_same_query!(
    apps,
    routes,
    views,
);
