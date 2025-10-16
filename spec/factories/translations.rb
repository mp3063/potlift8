FactoryBot.define do
  factory :translation do
    association :translatable, factory: :product
    locale { 'en' }
    key { 'name' }
    value { 'Translated Product Name' }

    trait :spanish do
      locale { 'es' }
      value { 'Nombre del Producto' }
    end

    trait :french do
      locale { 'fr' }
      value { 'Nom du Produit' }
    end

    trait :german do
      locale { 'de' }
      value { 'Produktname' }
    end

    trait :italian do
      locale { 'it' }
      value { 'Nome del Prodotto' }
    end

    trait :portuguese do
      locale { 'pt' }
      value { 'Nome do Produto' }
    end

    trait :name_translation do
      key { 'name' }
    end

    trait :description_translation do
      key { 'description' }
      value { 'Translated product description text' }
    end
  end
end
