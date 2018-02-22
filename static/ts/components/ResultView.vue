<template>
    <div>
        <Cell-View v-if="cell._result_type === 'OBJ'" v-bind:cell="cell.evaluate()"/>
        <Cell-List v-else-if="cell._result_type === 'ARR'" v-bind:cells="cell.evaluate()"/>
        <span v-else>{{ cell.toString() }}</span>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import * as util from '../utils';
import * as constants from '../constants';

export default Vue.component('ResultView', {
    name: 'ResultView',
    props: ['cell'],
    // computed: {
    //     isTable: function() : boolean {
    //         return (util.detectType(this.value) === constants.TYPE_ARRAY
    //          && this.value.length > 0 && util.detectType(this.value[0]) === constants.TYPE_ARRAY    // Has a row
    //          && this.value[0].length > 0 && util.detectType(this.value[0][0]) === constants.TYPE_OBJECT // Has atleast a column.
    //         ); 
    //     },
    //     columnNames: function() {
    //         // Extract column names from first row. Assume all rows follow same schema.
    //         return this.value[0].map((row) => row.key);
    //     },
    //     isArrResult: function() : boolean {
    //         return util.detectType(this.value) == constants.TYPE_ARRAY;
    //     },
    //     valType: function() : string {
    //         return util.detectType(this.value);
    //     },
    //     asStr: function() : string {
    //         return util.formatValue(this.value);
    //     }
    // }
});
</script>

<style>
</style>
