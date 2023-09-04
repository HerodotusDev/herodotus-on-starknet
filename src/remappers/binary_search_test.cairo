#[cfg(test)]
mod binary_search {
    use option::OptionTrait;
    use core::array::{ArrayTrait, SpanTrait};
    use traits::{Into, TryInto, PartialOrd};
    use debug::PrintTrait;

    fn custom_binary_search(arr: Span<u256>, x: u256) -> Option<u256> {
        let mut left: u256 = 0;
        let mut right: u256 = arr.len().into();
        loop {
            if left >= right {
                break;
            }

            let mid: u256 = (left + right) / 2;
            let mid_val: u256 = *arr.at(mid.try_into().unwrap());
            if x >= mid_val {
                left = mid + 1;
            } else {
                right = mid;
            }
            continue;
        };
        if left == 0 {
            return Option::None(());
        }
        return Option::Some(left - 1);
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_no_element() {
        let mut arr = ArrayTrait::new();
        let arr_span = arr.span();

        assert(custom_binary_search(arr_span, 43).is_none(), 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_single_element() {
        let mut arr = ArrayTrait::new();
        arr.append(42);

        let arr_span = arr.span();
        assert(custom_binary_search(arr_span, 42).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 43).unwrap() == 0, 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn test_binary_search_many_elements() {
        let mut arr = ArrayTrait::new();
        arr.append(1);
        arr.append(2);
        arr.append(3);
        arr.append(4);
        arr.append(5);

        let arr_span = arr.span();
        assert(custom_binary_search(arr_span, 0).is_none(), 'Unexpected result');
        assert(custom_binary_search(arr_span, 1).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 2).unwrap() == 1, 'Unexpected result');
        assert(custom_binary_search(arr_span, 3).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 4).unwrap() == 3, 'Unexpected result');
        assert(custom_binary_search(arr_span, 5).unwrap() == 4, 'Unexpected result');
        assert(custom_binary_search(arr_span, 6).unwrap() == 4, 'Unexpected result');
    }

    #[available_gas(9999999)]
    #[test]
    fn text_binary_search_many_elements_with_gaps() {
        let mut arr = ArrayTrait::new();
        arr.append(3);
        arr.append(8);
        arr.append(9);
        arr.append(14);

        let arr_span = arr.span();

        // Exact match for array with gaps
        assert(custom_binary_search(arr_span, 2).is_none(), 'Unexpected result');
        assert(custom_binary_search(arr_span, 3).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 4).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 7).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 8).unwrap() == 1, 'Unexpected result');
        assert(custom_binary_search(arr_span, 9).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 10).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 13).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 14).unwrap() == 3, 'Unexpected result');
        assert(custom_binary_search(arr_span, 15).unwrap() == 3, 'Unexpected result');

        // Closest to x
        assert(custom_binary_search(arr_span, 2).is_none(), 'Unexpected result');
        assert(custom_binary_search(arr_span, 3).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 4).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 7).unwrap() == 0, 'Unexpected result');
        assert(custom_binary_search(arr_span, 8).unwrap() == 1, 'Unexpected result');
        assert(custom_binary_search(arr_span, 9).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 10).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 13).unwrap() == 2, 'Unexpected result');
        assert(custom_binary_search(arr_span, 14).unwrap() == 3, 'Unexpected result');
        assert(custom_binary_search(arr_span, 15).unwrap() == 3, 'Unexpected result');
    }
}
