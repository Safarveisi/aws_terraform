locals {
    path_parts = split("/", path.cwd)
    name_prefix = element(local.path_parts, -1)
}