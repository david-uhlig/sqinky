[Sqids]: https://sqids.org/
[gem]: https://rubygems.org/gems/sqinky
[license]: https://github.com/david-uhlig/sqinky/blob/main/LICENSE.md
[tests]: https://github.com/david-uhlig/sqinky/actions/workflows/main.yml

![Sqinky – Sqids for your Active Record models](.github/assets/banner-dark.svg)

# Sqinky - 🦑 [Sqids] for your Active Record models.

[![Gem Version](http://img.shields.io/gem/v/sqinky.svg)][gem]
[![License: MIT](https://img.shields.io/github/license/david-uhlig/sqinky?label=License&labelColor=343B42&color=blue)][license]
[![Tests](https://github.com/david-uhlig/sqinky/actions/workflows/main.yml/badge.svg)][tests]

> **What is [Sqids]?**
> 
> Sqids (pronounced "squids") is an open-source library that lets you generate short unique identifiers from numbers. These IDs are URL-safe, can encode several numbers, and do not contain common profanity words.
> 
> This is what they look like: `https://example.com/CN4Xst`
> 
> Source: https://sqids.org/

Sqinky brings Sqids-based identifier encoding[^1] and decoding directly to your Active Record models. 

The library adds a thin access layer on top of [Sqids](https://sqids.org/) to work effortlessly with short, unique, and URL-safe identifiers. It supports encodings composed of multiple attributes and multiple encodings per model. Sqinky does not store encodings in the database. Instead, it decodes them on the fly back to the initial arguments and uses standard Active Record methods to retrieve the records.

#### Key features
- **Dynamic Encodings**: Computed from record attributes on the fly. No extra data is stored in the database.
- **Auto-generated Helpers**: Provides `find_by_*`, `find_by_*!`, `destroy_by_*`, and `delete_by_*` methods.
- **Multiple Attributes**: Encode and decode composite identifiers (e.g., `[account_id, id]`).
- **Customizable**: Pass any Sqids option (`alphabet`, `min_length`, and `blocklist`) per encoder.

## Installation

Run the following command to add Sqinky to your Gemfile:

```bash
bundle add sqinky
```

### Supported versions

Sqinky officially supports only the Ruby and Rails versions that still receive maintenance from their maintainers, see the [Ruby](https://www.ruby-lang.org/en/downloads/branches/) and [Rails](https://rubyonrails.org/maintenance) maintenance policies. The [test workflow](.github/workflows/main.yml) lists the versions currently tested.

The gemspec allows older versions (`ruby >= 3.3`, `activerecord >= 7.0`) so that you are not blocked from installing Sqinky. They may work, but they aren't tested, and bugs that only occur on end-of-life versions may not get fixed.

## Usage

To use it include `Sqinky::IdentifierEncoding` in your Active Record model and 
* add the `encodes_identifier` macro for a single attribute (defaults to `:id`), or  
* add the `encodes_identifiers` macro for multiple attributes.
* See [Parameter Overview](#parameter-overview) for all configuration options.

This generates the encoding methods `<attribute>_encoding` and `<attribute>_encoding!` (by default; configurable), and the dynamic Active Record methods `find_by_*`, `find_by_*!`, `delete_by_*`, and `destroy_by_*`. See [Generated Method Overview](#generated-methods-overview) for a detailed overview.

#### Basic usage
```ruby
class Comment < ApplicationRecord
  include Sqinky::IdentifierEncoding
  
  encodes_identifier :id
end

# Retrieving the encoding
comment = Comment.create!(text: "Sqinky is the linky that breaks when you drinky.")
comment.id # => 1
comment.id_encoding # => "Uk"

# Finding the comment back
Comment.find_by_id_encoding("Uk") # => #<Comment id: 1, ...>
Comment.find_by_id_encoding!("Uk") # Raises ActiveRecord::RecordNotFound if not found
Comment.destroy_by_id_encoding("Uk")
Comment.delete_by_id_encoding("Uk")
```

> [!WARNING]
> For consistent behavior only use attributes with `Integer` values `>= 0`.

> [!NOTE]
> `id_encoding` in all these methods is dynamically generated from the `id` attribute. 
> * If you encode a different attribute, e.g. `user_id` the method names change to  `user_id_encoding`. 
> * Composite encodings are connected with `_and_` in the specified order: `id_and_user_id_encoding`. 
> * You can choose your own name with the `as:` parameter: `as: :token # => instance.token`.

#### Most common workflow
1. Receive encoding from a **persisted** record: `user.id_encoding # => "Uk"`.
2. Pass the encoding around, either via URL `/users/Uk/show` or store it in a session.
3. Retrieve the record through the encoding `User.find_by_id_encoding("Uk") # => #<User id: 1, ...>`

### Multiple Attributes & Custom Names

Sqinky can compose multiple attributes into a single encoding, here: `:id` and `:account_id`. Normally, this would dynamically generate `id_and_account_id_encoding` methods, but here we rename them to `token` with the `as:` parameter.

```ruby
class Invitation < ApplicationRecord
  include Sqinky::IdentifierEncoding

  # Encode both `id` and `account_id` into a single `token`
  encodes_identifiers :id, :account_id, as: :token
end

invitation = Invitation.create!(account_id: 42)
invitation.token # => "ySrS"

# Internally calls find_by(id: 1, account_id: 42)
Invitation.find_by_token("ySrS")
```

> [!NOTE]
> Mind the pluralized `encodes_identifiers` when encoding multiple attributes.

### Decoding Helper

If you need to access the decoded hash, you can pass your preferred method name to the `decodes_as:` parameter, e.g. `decodes_as: :id_decoding`. This will generate a dynamic class method, that takes a single argument: the encoding. 

```ruby
class Order < ApplicationRecord
  include Sqinky::IdentifierEncoding

  encodes_identifier :id, as: :public_id, decodes_as: :decode_public_id
end

Order.decode_public_id("Uk") # => { id: 1 }
```

### Custom Sqids Options

Configure Sqids by passing in the [Sqids options](https://github.com/sqids/sqids-ruby?tab=readme-ov-file#%E2%80%8D-examples): `alphabet`, `min_length`, and `blocklist`. Each coder can have its own configuration.

```ruby
class Comment < ApplicationRecord
  include Sqinky::IdentifierEncoding

  encodes_identifier :id, alphabet: "abcdef0123456789", min_length: 10
end
```

> [!IMPORTANT]
> Sqids encodings are not encrypted. With the default alphabet, `"Uk"` means `1` in every app that uses Sqids, and anyone can decode an encoding with the public Sqids library. Use encodings to shorten URLs and hide sequential IDs from casual view, not for access control: always authorize access to the record you find. To make encodings app-specific, pass a shuffled `alphabet:` before you issue any encodings, since changing it later breaks existing ones (see [Changing Sqids options](#changing-sqids-options)).

### Multiple Encodings

A model can have multiple encodings, even for the same attribute, as long as they have distinct `as:` method names.

```ruby
class Post < ApplicationRecord
  include Sqinky::IdentifierEncoding
  
  encodes_identifier
  encodes_identifiers :id, :tenant_id
end

post = Post.create!(title: "How Sqinky became so inkie.")
post.id # => 212
post.tenant_id # => 42
post.id_encoding # => "37E"
post.id_and_tenant_id_encoding # => "jGTwn"

Post.find_by_id_encoding("37E") # => #<Post id: 212, ...>
Post.find_by_id_and_tenant_id_encoding("jGTwn") # => #<Post id: 212, ...>
```

### Inheritance

Since Sqinky generates regular methods, it can be included anywhere in the class tree. Child classes can use the parents' methods or overwrite them with their own. It isn't required for the including class to have the configured attributes.

```ruby
class ApplicationRecord < ActiveRecord::Base
  include Sqinky::IdentifierEncoding
  
  encodes_identifier
end

class Label < ApplicationRecord
end

label = Label.create!(text: "Pinky")
label.id = 1
label.id_encoding # => "Uk"
```

### Method Name Collisions

Sqinky raises an `ArgumentError` instead of replacing a method that already exists. This includes attributes like `id`, methods inherited from Active Record like `to_param`, your own methods, and the methods of another encoding in the same class. Redeclaring an encoding inherited from a parent class is allowed.

```ruby
class Comment < ApplicationRecord
  include Sqinky::IdentifierEncoding

  encodes_identifier as: :id # => ArgumentError: Comment already defines #id. Choose a different name with `as:` or `decodes_as:`.
end
```

To use an encoding in URLs, give it its own name and delegate to it:

```ruby
class Comment < ApplicationRecord
  include Sqinky::IdentifierEncoding

  encodes_identifier as: :token

  def to_param = token
end
```

> [!WARNING]
> Database columns can't be detected, because Active Record defines their reader methods lazily. Don't name an encoding after one of the model's columns: the encoding would hide the column's reader.

### Changing Sqids options

By default only canonical encodings are accepted, so every record has exactly one valid encoding. As a consequence, changing a Sqids option invalidates previously issued encodings. This includes raising `min_length`: `"Uk"` still decodes to `[1]`, but the canonical encoding becomes `"UkLWZg9DAJ"`, so `"Uk"` is rejected.

If old encodings must keep working after raising `min_length` or changing `blocklist`, pass `canonical: false`. Encodings with the wrong number of values are still rejected, but several encodings may then resolve to the same record.

```ruby
class Comment < ApplicationRecord
  include Sqinky::IdentifierEncoding

  # Issues "UkLWZg9DAJ", but still accepts the previously issued "Uk".
  encodes_identifier :id, min_length: 10, canonical: false
end
```

> [!WARNING]
> Never change `alphabet` once encodings are issued: old encodings then decode to different values and resolve to the wrong records, regardless of `canonical`.

### Parameter Overview

#### `encodes_identifier`

| Parameter         | Default | Description                                                                                 |
|-------------------|---------|---------------------------------------------------------------------------------------------|
| `attribute`       | `:id`   | The attribute to encode. Should only have `Integer` `>= 0` values.                          |
| `as:`             | `nil`   | If `nil` inferred as `<attribute>_encoding`.                                                |
| `decodes_as:`     | `nil`   | Name of the decoding class method. If `nil` no such method is generated.                    |
| `canonical:`      | `true`  | If `false`, also accept non-canonical encodings. See [Changing Sqids options](#changing-sqids-options). |
| `**sqids_options` | `{}`    | Sqids options passed through to `Sqids.new`, e.g. `min_length`, `alphabet`, and `blocklist` |

#### `encodes_identifiers`

| Parameter         | Default | Description                                                                                  |
|-------------------|---------|----------------------------------------------------------------------------------------------|
| `*attributes`     |         | The attribute(s) to encode. Should only have `Integer` `>= 0` values.                        |
| `as:`             | `nil`   | If `nil` inferred as `<attribute[_and_<attribute>]>_encoding`.                               |
| `decodes_as:`     | `nil`   | Name of the decoding class method. If `nil` no such method is generated.                     |
| `canonical:`      | `true`  | If `false`, also accept non-canonical encodings. See [Changing Sqids options](#changing-sqids-options).  |
| `**sqids_options` | `{}`    | Sqids options passed through to `Sqids.new`, e.g. `min_length`, `alphabet`, and `blocklist`. |

### Generated Methods Overview

Sqinky generates these methods when invoking `encodes_identifier(s)`:

| Method                            | Description                                                                                        |
|-----------------------------------|----------------------------------------------------------------------------------------------------|
| `instance.<as>`                   | Returns the Sqids encoding for the configured attributes. Returns `nil` if any attribute is blank, raises `ArgumentError` if any attribute is not an `Integer`. |
| `instance.<as>!`                  | Same as above, but also raises `ArgumentError` instead of returning `nil` for blank attributes.    |
| `Class.<decodes_as>(encoding)`    | Returns the decoded hash, e.g. `{ id: 42 }`, or `nil` if the encoding is invalid.                  |
| `Class.find_by_<as>(encoding)`    | Decodes `encoding` and passes the decoded hash to `find_by(...)`.                                  |
| `Class.find_by_<as>!(encoding)`   | Decodes `encoding` and passes the decoded hash to `find_by!(...)`.                                 |
| `Class.destroy_by_<as>(encoding)` | Decodes `encoding` and passes the decoded hash to `destroy_by(...)`.                               |
| `Class.delete_by_<as>(encoding)`  | Decodes `encoding` and passes the decoded hash to `delete_by(...)`.                                |

> [!NOTE]
> Invalid encodings never reach the database. An encoding is valid if it is a non-empty `String`, no longer than the longest encoding the encoder can issue (or 255 characters with `canonical: false`), that decodes to exactly one value per configured attribute, none of them above `Sqids.max_value`, and, unless `canonical: false` is set, is the canonical Sqids encoding of those values. For an invalid encoding `find_by_<as>` returns `nil`, `find_by_<as>!` raises `ActiveRecord::RecordNotFound`, `destroy_by_<as>` returns `[]`, and `delete_by_<as>` returns `0`.


## Development

### Setup

After checking out the repo, run the setup script to install dependencies:

```bash
bin/setup
```

This project uses [mise](https://mise.jdx.dev/) for managing Ruby versions and tasks. If you have mise installed, you can use it to run common tasks.

### Scripts & Tasks

- `bin/console`: Open an interactive prompt to experiment with the code.
- `rake spec`: Run the test suite.
- `rake standard`: Run the StandardRB linter.
- `bundle exec appraisal install`: Install the dependencies for all supported Rails versions.
- `bundle exec appraisal rake spec`: Run tests against all supported Rails versions.
- `mise run ci`: Run the local CI pipeline (linting and multi-Rails tests).

## Versioning

This library aims to adhere to [Semantic Versioning 2.0.0](http://semver.org/). Violations of this scheme should be reported as bugs.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/david-uhlig/sqinky. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/david-uhlig/sqinky/blob/main/CODE_OF_CONDUCT.md).

Please report security vulnerabilities privately as described in the [security policy](SECURITY.md).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.md).

[^1]: In the context of this library the term `encoding` refers to the output of `Sqids.new.encode([<number>])`. In Sqids terminology this is a *short unique identifier from numbers*.
