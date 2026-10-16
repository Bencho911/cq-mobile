import 'models.dart';

// MOCK: datos locales de respaldo para cuando el backend no está
// disponible (USE_MOCKS=true por defecto). No representan datos reales.

const mockCategories = [
  ProductCategory(codCat: 1, name: 'Café'),
  ProductCategory(codCat: 2, name: 'Sin café'),
  ProductCategory(codCat: 3, name: 'Pastelería'),
];

const mockProducts = [
  Product(
    codProd: 1,
    name: 'Café con leche',
    description: 'Americano con hielo y leche fresca.',
    price: 25000,
    imageUrl: 'assets/products/cafeconleche.webp',
    categoryIds: [1],
    stock: 12,
    stockMin: 4,
  ),
  Product(
    codProd: 2,
    name: 'Cocoa Caramel Latte',
    description: 'Leche al vapor con salsas de moca y caramelo.',
    price: 35500,
    discount: 7,
    imageUrl: 'assets/products/cocoalatte.webp',
    categoryIds: [1],
    stock: 8,
    stockMin: 3,
  ),
  Product(
    codProd: 3,
    name: 'Nitro Cold Brew',
    description: 'Cold brew con nitrógeno, sin azúcar y crema aterciopelada.',
    price: 31000,
    imageUrl: 'assets/products/nitro.webp',
    categoryIds: [1],
    stock: 6,
    stockMin: 2,
  ),
  Product(
    codProd: 4,
    name: 'Caffè Mocha',
    description: 'Espresso con salsa de moca, leche y crema batida.',
    price: 29000,
    imageUrl: 'assets/products/macha.webp',
    categoryIds: [1],
    stock: 10,
    stockMin: 3,
  ),
  Product(
    codProd: 5,
    name: 'Caramel Latte',
    description: 'Espresso, leche fresca y caramelo.',
    price: 28000,
    discount: 10,
    imageUrl: 'assets/products/caramel_latte.webp',
    categoryIds: [1],
    stock: 15,
    stockMin: 5,
  ),
];

const mockStores = [
  Store(
    id: 1,
    name: 'Café Quindío · Centro',
    address: 'Calle 12 #9-34, Armenia, Quindío',
    phone: '+57 300 000 0001',
    status: 'ABIERTO',
    city: 'Armenia',
  ),
  Store(
    id: 2,
    name: 'Café Quindío · Norte',
    address: 'Cra 19 #22-15, Armenia, Quindío',
    phone: '+57 300 000 0002',
    status: 'ABIERTO',
    city: 'Armenia',
  ),
  Store(
    id: 3,
    name: 'Café Quindío · Aeropuerto',
    address: 'Terminal aérea, local 12',
    phone: '+57 300 000 0003',
    status: 'CERRADO',
    city: 'Armenia',
  ),
];

/// MOCK: usuario de la demo (el backend aún no expone el perfil).
const mockUserFirstName = 'Santiago';

/// MOCK: productos del último pedido, para "Lo de siempre".
const mockLastOrderProductIds = [3, 5];

/// MOCK: minutos estimados de preparación hasta que la tienda los informe.
const mockReadyMinutes = 6;
