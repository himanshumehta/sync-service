FactoryBot.define do
  factory :contact do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "John" }
    last_name { "Doe" }
    company { "Acme Corp" }
    status { :active }

    trait :inactive do
      status { :inactive }
    end

    trait :deleted do
      status { :deleted }
    end

    trait :without_company do
      company { nil }
    end
  end
end
