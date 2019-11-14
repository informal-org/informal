table! {
    apps (id) {
        id -> Int4,
        app_name -> Varchar,
        domain -> Varchar,
        environment -> Int2,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}

table! {
    routes (id) {
        id -> Int4,
        app_id -> Int4,
        view_id -> Int4,
        route_name -> Nullable<Varchar>,
        pattern -> Varchar,
        pattern_regex -> Varchar,
        method_get -> Bool,
        method_post -> Bool,
        extra_methods -> Nullable<Array<Int2>>,
    }
}

table! {
    views (id) {
        id -> Int4,
        app_id -> Int4,
        view_name -> Nullable<Varchar>,
        mime_type -> Varchar,
        asset_url -> Nullable<Varchar>,
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
