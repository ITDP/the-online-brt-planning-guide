package html;

typedef BreadcrumbItem = {
	no:Int,
	name:Html,
	url:String
}

typedef Breadcrumbs = {
	?volume:BreadcrumbItem,
	?chapter:BreadcrumbItem,
	?section:BreadcrumbItem
}

