/*
 * airbattery-mobile.c
 *
 * Narrow libimobiledevice helper owned by AirBattery.
 *
 * Keeps the native mobile-device stack out of the Swift process so failures in
 * libimobiledevice remain isolated to this child process. The output contract is
 * deliberately small and machine-readable.
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include <libimobiledevice/companion_proxy.h>
#include <libimobiledevice/libimobiledevice.h>
#include <plist/plist.h>

#define TOOL_LABEL "airbattery-mobile"

static void json_string(const char *value)
{
    const unsigned char *p = (const unsigned char *)(value ? value : "");
    putchar('"');
    while (*p) {
        switch (*p) {
        case '"':
            fputs("\\\"", stdout);
            break;
        case '\\':
            fputs("\\\\", stdout);
            break;
        case '\b':
            fputs("\\b", stdout);
            break;
        case '\f':
            fputs("\\f", stdout);
            break;
        case '\n':
            fputs("\\n", stdout);
            break;
        case '\r':
            fputs("\\r", stdout);
            break;
        case '\t':
            fputs("\\t", stdout);
            break;
        default:
            if (*p < 0x20) {
                fprintf(stdout, "\\u%04x", *p);
            } else {
                putchar(*p);
            }
        }
        p++;
    }
    putchar('"');
}

static idevice_error_t open_parent(const char *udid, idevice_t *device)
{
    enum idevice_options options =
        IDEVICE_LOOKUP_USBMUX | IDEVICE_LOOKUP_NETWORK | IDEVICE_LOOKUP_PREFER_NETWORK;
    return idevice_new_with_options(device, udid, options);
}

static companion_proxy_error_t start_companion(idevice_t device, companion_proxy_client_t *client)
{
    *client = NULL;
    return companion_proxy_client_start_service(device, client, TOOL_LABEL);
}

static companion_proxy_error_t registry_value(
    idevice_t device,
    const char *watch_udid,
    const char *key,
    plist_t *value
) {
    companion_proxy_client_t client = NULL;
    companion_proxy_error_t error = start_companion(device, &client);
    if (error != COMPANION_PROXY_E_SUCCESS) {
        return error;
    }

    error = companion_proxy_get_value_from_registry(client, watch_udid, key, value);
    companion_proxy_client_free(client);
    return error;
}

static char *copy_registry_string(idevice_t device, const char *watch_udid, const char *key)
{
    plist_t dictionary = NULL;
    if (registry_value(device, watch_udid, key, &dictionary) != COMPANION_PROXY_E_SUCCESS ||
        dictionary == NULL) {
        if (dictionary) {
            plist_free(dictionary);
        }
        return NULL;
    }

    plist_t node = plist_dict_get_item(dictionary, key);
    char *result = NULL;
    if (node && plist_get_node_type(node) == PLIST_STRING) {
        plist_get_string_val(node, &result);
    }
    plist_free(dictionary);
    return result;
}

static int copy_registry_int(
    idevice_t device,
    const char *watch_udid,
    const char *key,
    int *value
) {
    plist_t dictionary = NULL;
    if (registry_value(device, watch_udid, key, &dictionary) != COMPANION_PROXY_E_SUCCESS ||
        dictionary == NULL) {
        if (dictionary) {
            plist_free(dictionary);
        }
        return 0;
    }

    plist_t node = plist_dict_get_item(dictionary, key);
    int ok = 0;
    if (node) {
        plist_type type = plist_get_node_type(node);
        if (type == PLIST_UINT) {
            uint64_t raw = 0;
            plist_get_uint_val(node, &raw);
            *value = (int)raw;
            ok = 1;
        } else if (type == PLIST_BOOLEAN) {
            uint8_t raw = 0;
            plist_get_bool_val(node, &raw);
            *value = raw ? 1 : 0;
            ok = 1;
        } else if (type == PLIST_STRING) {
            char *raw = NULL;
            plist_get_string_val(node, &raw);
            if (raw) {
                char *end = NULL;
                long parsed = strtol(raw, &end, 10);
                if (end && *end == '\0') {
                    *value = (int)parsed;
                    ok = 1;
                } else if (strcasecmp(raw, "true") == 0 ||
                           strcasecmp(raw, "yes") == 0) {
                    *value = 1;
                    ok = 1;
                } else if (strcasecmp(raw, "false") == 0 ||
                           strcasecmp(raw, "no") == 0) {
                    *value = 0;
                    ok = 1;
                }
                free(raw);
            }
        }
    }

    plist_free(dictionary);
    return ok;
}

static int companion_battery(const char *parent_udid)
{
    idevice_t device = NULL;
    if (open_parent(parent_udid, &device) != IDEVICE_E_SUCCESS || device == NULL) {
        fprintf(stderr, "airbattery-mobile: parent device not found: %s\n", parent_udid);
        return 3;
    }

    companion_proxy_client_t client = NULL;
    companion_proxy_error_t error = start_companion(device, &client);
    if (error != COMPANION_PROXY_E_SUCCESS) {
        fprintf(stderr, "airbattery-mobile: companion proxy start failed: %d\n", error);
        idevice_free(device);
        return 4;
    }

    plist_t registry = NULL;
    error = companion_proxy_get_device_registry(client, &registry);
    companion_proxy_client_free(client);

    if (error == COMPANION_PROXY_E_NO_DEVICES) {
        printf("{\"parent\":");
        json_string(parent_udid);
        printf(",\"watches\":[]}\n");
        idevice_free(device);
        return 0;
    }

    if (error != COMPANION_PROXY_E_SUCCESS || registry == NULL ||
        plist_get_node_type(registry) != PLIST_ARRAY) {
        fprintf(stderr, "airbattery-mobile: companion registry failed: %d\n", error);
        if (registry) {
            plist_free(registry);
        }
        idevice_free(device);
        return 5;
    }

    printf("{\"parent\":");
    json_string(parent_udid);
    printf(",\"watches\":[");

    uint32_t count = plist_array_get_size(registry);
    int emitted = 0;
    for (uint32_t i = 0; i < count; i++) {
        plist_t item = plist_array_get_item(registry, i);
        if (!item || plist_get_node_type(item) != PLIST_STRING) {
            continue;
        }

        char *watch_udid = NULL;
        plist_get_string_val(item, &watch_udid);
        if (!watch_udid || !*watch_udid) {
            free(watch_udid);
            continue;
        }

        char *name = copy_registry_string(device, watch_udid, "DeviceName");
        char *product_type = copy_registry_string(device, watch_udid, "ProductType");
        int battery_level = -1;
        int is_charging = 0;
        int has_battery = copy_registry_int(
            device,
            watch_udid,
            "BatteryCurrentCapacity",
            &battery_level
        );
        int has_charging = copy_registry_int(
            device,
            watch_udid,
            "BatteryIsCharging",
            &is_charging
        );

        if (has_battery && battery_level >= 0 && battery_level <= 100) {
            if (emitted) {
                putchar(',');
            }
            printf("{\"id\":");
            json_string(watch_udid);
            printf(",\"name\":");
            json_string(name ? name : "Apple Watch");
            printf(",\"productType\":");
            json_string(product_type ? product_type : "Watch");
            printf(",\"batteryLevel\":%d,\"isCharging\":%s}",
                   battery_level,
                   has_charging && is_charging ? "true" : "false");
            emitted = 1;
        }

        free(name);
        free(product_type);
        free(watch_udid);
    }

    printf("]}\n");
    plist_free(registry);
    idevice_free(device);
    return 0;
}

static void usage(FILE *stream)
{
    fprintf(
        stream,
        "Usage:\n"
        "  airbattery-mobile companion-battery <parent-udid>\n"
        "\n"
        "Commands emit JSON on stdout and diagnostics on stderr.\n"
    );
}

int main(int argc, char **argv)
{
    if (argc != 3 || strcmp(argv[1], "companion-battery") != 0) {
        usage(stderr);
        return 2;
    }
    return companion_battery(argv[2]);
}
