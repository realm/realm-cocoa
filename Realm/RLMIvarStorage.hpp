////////////////////////////////////////////////////////////////////////////
//
// Copyright 2021 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import <type_traits>

// This type "hides" the wrapped type from the objective-c runtime. Each ivar
// and method in an obj-c class has a type signature which is a string
// representing the type of that thing. For C++ types, the signature can get
// extremely large (upwards of 10 KB) due to that it includes all of the member
// variables and their very long type names. Storing the object in untyped
// storage works around this by just having a consistent small signature.
template<typename T>
class RLMIvar {
public:
    RLMIvar() noexcept(noexcept(T())) __attribute__((always_inline)) {
        new (&_storage) T;
    }

    ~RLMIvar() __attribute__((always_inline)) {
        delete value();
    }

    RLMIvar& operator=(T const& rhs) noexcept(std::is_nothrow_copy_assignable<T>::value) __attribute__((always_inline)) {
        *value() = rhs;
        return *this;
    }

    RLMIvar& operator=(T&& rhs) noexcept(std::is_nothrow_move_assignable<T>::value) __attribute__((always_inline)) {
        *value() = std::move(rhs);
        return *this;
    }

    T *_Nonnull operator->() noexcept __attribute__((always_inline)) {
        return value();
    }

    T& operator*() noexcept __attribute__((always_inline)) {
        return *value();
    }

    operator T&() noexcept __attribute__((always_inline)) {
        return *value();
    }

private:
    std::aligned_storage<sizeof(T)> _storage;
    T *_Nonnull value() noexcept __attribute__((always_inline)) {
        return reinterpret_cast<T*>(&_storage);
    }
};

