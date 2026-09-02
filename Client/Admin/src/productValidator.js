export const PRODUCT_URL_PATTERN = "https?://.+";
export const PRODUCT_URL_TITLE = "URL must start with http:// or https://";

function toTrimmedString(value) {
    return String(value ?? "").trim();
}

function isValidName(value) {
    return toTrimmedString(value).length >= 2;
}

function isValidDouble(value) {
    const normalized = toTrimmedString(value);
    return normalized !== "" && Number.isFinite(Number(normalized));
}

function isValidUrl(value) {
    return /^https?:\/\/.+/i.test(toTrimmedString(value));
}

export function validateProductForm(productForm = {}) {
    const productName = toTrimmedString(productForm.name);
    const storeName = toTrimmedString(productForm.storeName);
    const category = toTrimmedString(productForm.category);
    const price = toTrimmedString(productForm.price);
    const weight = toTrimmedString(productForm.weight);
    const image = toTrimmedString(productForm.image);
    const storeLink = toTrimmedString(productForm.storeLink);

    if (productName === "") {
        return { error: "Product name is required" };
    }

    if (!isValidName(productName)) {
        return { error: "Enter valid product name" };
    }

    if (storeName === "") {
        return { error: "Brand name is required" };
    }

    if (!isValidName(storeName)) {
        return { error: "Enter valid brand name" };
    }

    if (weight === "") {
        return { error: "Weight is required" };
    }

    if (!isValidDouble(weight)) {
        return { error: "Invalid weight" };
    }

    if (Number(weight) <= 0) {
        return { error: "Weight must be greater than 0" };
    }

    if (Number(weight) > 20) {
        return { error: "Weight max is 20" };
    }

    if (price === "") {
        return { error: "Price is required" };
    }

    if (!isValidDouble(price)) {
        return { error: "Invalid price" };
    }

    if (Number(price) <= 0) {
        return { error: "Price must be greater than 0" };
    }

    if (category === "") {
        return { error: "Category is required" };
    }

    if (image === "") {
        return { error: "Image URL is required" };
    }

    if (!isValidUrl(image)) {
        return { error: "Image URL must start with http:// or https://" };
    }

    if (storeLink === "") {
        return { error: "Product URL is required" };
    }

    if (!isValidUrl(storeLink)) {
        return { error: "Product URL must start with http:// or https://" };
    }

    return {
        error: "",
        payload: {
            name: productName,
            image,
            storeName,
            storeLink,
            price: Number(price),
            weight: Number(weight),
            category,
            tags: [category.toLowerCase(), storeName.toLowerCase()],
            status: productForm.status || "active",
        },
    };
}
