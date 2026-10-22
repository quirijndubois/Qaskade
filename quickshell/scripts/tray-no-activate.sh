#!/bin/bash
# Prints the Id of every registered StatusNotifierItem that has no Activate
# method (e.g. Steam's Ayatana indicator). Left-clicking those can't do
# anything, so the tray opens their menu instead.
items=$(busctl --user --json=short get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null \
    | grep -oE '"data":\[[^]]*\]' | grep -oE '"[^"]+"' | tr -d '"' | grep -v '^data$')

for entry in $items; do
    if [[ $entry == */* ]]; then
        svc=${entry%%/*}; path=/${entry#*/}
    else
        svc=$entry; path=/StatusNotifierItem
    fi
    busctl --user introspect "$svc" "$path" org.kde.StatusNotifierItem 2>/dev/null \
        | grep -q '^\.Activate ' && continue
    busctl --user get-property "$svc" "$path" org.kde.StatusNotifierItem Id 2>/dev/null \
        | sed -n 's/^s "\(.*\)"$/\1/p'
done
