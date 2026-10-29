# Maps and figures for the reports (ggplot2 + patchwork).

suppressPackageStartupMessages({library(sf); library(dplyr); library(tidyr); library(ggplot2); library(patchwork)})

# axes in longitude / latitude
LONLAT = st_crs(4326)

LABELS = c(
	poi_retail = "Retail and trade", poi_transport = "Transportation", poi_essential = "Essential services",
	poi_health = "Health facilities", poi_food = "Food and beverage", poi_recreation = "Recreation",
	poi_education = "Education", poi_religious = "Religious and community", poi_industrial = "Industrial land use",
	poi_buildings = "Residential and commercial buildings", poi_other = "Other", n_pharmacy = "Pharmacies",
	built_share = "Built-up", lu_residential = "Residential", lu_commercial = "Commercial",
	lu_industrial = "Industrial", lu_agricultural = "Agricultural", lu_green = "Green and natural",
	income_median = "Median income (EUR)", gini = "Gini index", pct_65plus = "Aged 65+ (share)",
	hh_size = "People per household", pct_foreign = "Foreign nationality (share)",
	pct_rented = "Rented dwellings", density = "Residents per km²")

# Health facilities in red; no other category uses red
POI_COLOURS = c(poi_health = "#d7191c", poi_retail = "#1f78b4", poi_transport = "#6a3d9a",
	poi_essential = "#33a02c", poi_food = "#ff7f00", poi_recreation = "#b2df8a", poi_education = "#a6611a",
	poi_religious = "#e7a1c8", poi_buildings = "#a6cee3", poi_industrial = "#cccccc", poi_other = "#e0e0e0")

theme_map = function() theme_minimal(base_size = 10) +
	theme(legend.position = "bottom", axis.text = element_text(size = 7), plot.title = element_text(size = 11))

# Restrictions in force in a region during the window (NPI, helpers/restrictions.R)
npi = function(name) {
	n = NPI[NPI$region %in% c("ES", region(name)$code), ]
	n[n$start <= WINDOW[2], ]
}

# "Second state of alarm" + "Curfew" -> "Second state of alarm and curfew"
join_labels = function(x, sep = " and ") if (length(x)) paste(c(x[1], tolower(x[-1])), collapse = sep) else ""

# Policy periods: a new one starts whenever a measure starts or ends
periods = function(name) {
	n = npi(name)
	start = sort(unique(c(WINDOW[1], n$start, n$end + 1)))
	start = start[start <= WINDOW[2]]
	p = data.frame(start = start, end = c(start[-1] - 1, WINDOW[2]))
	inforce = vapply(seq_len(nrow(p)), \(i) join_labels(unique(n$label[n$start <= p$start[i] & n$end >= p$start[i]]), "\nand "), "")
	p$label = paste0(ifelse(nzchar(inforce), inforce, "No state of alarm"), "\n",
		format(p$start, "%d %b %Y"), " - ", format(p$end, "%d %b %Y"))
	p
}

# Measure starts and ends as dashed lines; measures under 30 days as dotted bands
npi_events = function(name) {
	n = npi(name)
	short = n$end - n$start < 30
	long = n[!short, ]
	lines = data.frame(start = c(long$start, long$end + 1), text = c(long$label, paste(long$label, "ends"))) |>
		filter(start > WINDOW[1], start <= WINDOW[2]) |>
		summarise(text = join_labels(unique(text), "\nand "), .by = start)
	list(lines = lines, bands = n[short, c("start", "end", "label")])
}

# One thin line per BHA, a smoothed regional trend, restrictions marked;
# log = TRUE: log(1 + y) axis, so the spread between BHAs stays readable
plot_spaghetti = function(x, var, title, ylab, events, log = FALSE) {
	top = max(x[[var]], na.rm = TRUE)
	y = if (log)
		scale_y_continuous(transform = "log1p", breaks = c(0, 10^(0:5)), labels = \(b) format(b, big.mark = ",", scientific = FALSE, trim = TRUE))
	else
		scale_y_continuous()
	b = events$bands
	ggplot(x, aes(week, .data[[var]])) +
		annotate("rect", xmin = b$start, xmax = b$end + 1, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.6) +
		geom_line(aes(group = id), linewidth = 0.1, alpha = 0.25, colour = "grey40") +
		geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs", k = 30), colour = "#d7191c", se = FALSE, linewidth = 0.5) +
		geom_vline(xintercept = events$lines$start, linetype = "dashed", colour = "grey30") +
		geom_vline(xintercept = c(b$start, b$end + 1), linetype = "dotted", colour = "grey30") +
		annotate("text", x = events$lines$start, y = top, label = events$lines$text, hjust = -0.05, vjust = 1, size = 3) +
		annotate("text", x = b$start, y = top, label = b$label, hjust = -0.05, vjust = 3.2, size = 3) +
		y +
		coord_cartesian(ylim = c(0, top), expand = FALSE) +
		scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
		labs(x = NULL, y = ylab, title = title) +
		theme_minimal(base_size = 10) +
		theme(panel.grid.minor = element_blank())
}

# Class labels from breaks, e.g. "7,400-8,300"
class_labels = function(breaks, fmt = \(b) format(signif(b, 2), big.mark = ",", trim = TRUE))
	paste0(fmt(head(breaks, -1)), "-", fmt(breaks[-1]))

# One colour per class
class_scale = function(labels, palette, key, reverse = FALSE) {
	cols = RColorBrewer::brewer.pal(max(3, length(labels)), palette)[seq_along(labels)]
	scale_fill_manual(values = setNames(if (reverse) rev(cols) else cols, labels), drop = FALSE, name = key)
}

map_classes = function(bha, x, var, breaks, labels, scale)
	ggplot(left_join(bha["id"], x, by = "id") |>
			mutate(class = cut(.data[[var]], breaks, labels, include.lowest = TRUE))) +
		geom_sf(aes(fill = class), colour = "white", linewidth = 0.03) +
		scale + coord_sf(datum = LONLAT) + theme_map() +
		guides(fill = guide_legend(nrow = 1))

# Per-BHA values with different units: one map per variable, each with its own key
map_values = function(x, bha, vars, title, palette = "YlOrRd") {
	g = left_join(bha["id"], x, by = "id")
	panel = \(v) {
		brks = unique(classInt::classIntervals(g[[v]], n = 5, style = "fisher")$brks)
		ggplot(g) +
			geom_sf(aes(fill = .data[[v]]), colour = "grey70", linewidth = 0.03) +
			scale_fill_stepsn(colours = RColorBrewer::brewer.pal(5, palette), breaks = brks[-c(1, length(brks))],
				limits = range(brks), name = NULL, labels = \(b) format(signif(b, 2), big.mark = ",")) +
			coord_sf(datum = LONLAT) +
			labs(title = LABELS[[v]]) +
			theme_map() +
			theme(legend.key.width = unit(1.2, "cm"))
	}
	wrap_plots(lapply(vars, panel), ncol = 3) + plot_annotation(title = title)
}

# Same unit across variables: one facet per variable, one shared classed key
map_facets = function(x, bha, vars, breaks, labels, palette, key, title, facet_labels = LABELS[vars]) {
	g = left_join(bha["id"], x, by = "id") |>
		pivot_longer(all_of(vars)) |>
		mutate(name = factor(setNames(facet_labels, vars)[name], facet_labels),
			class = cut(value, breaks, labels, include.lowest = TRUE))
	ggplot(g) +
		geom_sf(aes(fill = class), colour = NA) +
		geom_sf(data = st_geometry(bha), fill = NA, colour = "white", linewidth = 0.03) +
		scale_fill_brewer(palette = palette, drop = FALSE, name = key) +
		facet_wrap(~ name, ncol = 3) +
		coord_sf(datum = LONLAT) +
		labs(title = title) +
		theme_map() +
		guides(fill = guide_legend(nrow = 1))
}

# Points of interest by category, health facilities drawn on top
map_pois = function(pts, bha, title) {
	p = filter(pts, !is.na(category)) |> mutate(health = category == "poi_health") |> arrange(health)
	ggplot() +
		geom_sf(data = bha, fill = "grey97", colour = "grey60", linewidth = 0.1) +
		geom_sf(data = p, aes(colour = category, size = health), alpha = 0.5) +
		scale_colour_manual(values = POI_COLOURS, labels = LABELS, name = NULL) +
		scale_size_manual(values = c(`FALSE` = 0.03, `TRUE` = 0.12), guide = "none") +
		guides(colour = guide_legend(override.aes = list(size = 2.5, alpha = 1), ncol = 2)) +
		coord_sf(datum = LONLAT) +
		labs(title = title) +
		theme_map() +
		theme(legend.position = "right")
}

# Sections with the share of their residents living in their point-assigned BHA
section_check = function(name) {
	bha = bha_geometry(name)
	provs = region(name)$provs
	sec = read_sections(bha, provs)
	share = section_lookup(bha, provs, sec) |>
		left_join(section_weights(bha, provs, "population", sec), by = c("cusec", "id")) |>
		mutate(share = coalesce(w, 0)) |>
		select(cusec, id, share)
	sec = sec |>
		left_join(share, by = "cusec") |>
		mutate(share_class = cut(share, c(-Inf, .5, .9, .99, Inf), right = FALSE,
			labels = c("< 50%", "50-90%", "90-99%", ">= 99%")))
	list(bha = bha, sections = sec)
}

# Covariates under both rules, long: one row per BHA and covariate
rule_comparison = function(name, vars = c("income_median", "pct_65plus", "pct_foreign", "pct_rented", "density")) {
	long = \(rule) read_table(name, census_table(rule)) |>
		select(id, all_of(vars)) |>
		pivot_longer(-id, values_to = rule)
	inner_join(long("population"), long("point"), by = c("id", "name")) |>
		mutate(diff_pct = 100 * (population - point) / point)
}

plot_rule_scatter = function(d, title)
	ggplot(mutate(d, name = LABELS[name]), aes(point, population)) +
		geom_abline(colour = "grey60") +
		geom_point(size = 0.6, alpha = 0.6) +
		facet_wrap(~ name, scales = "free") +
		labs(x = "point rule", y = "population rule", title = title) +
		theme_minimal()
