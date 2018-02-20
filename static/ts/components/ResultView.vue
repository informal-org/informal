<template>
    <div>
        <!-- <label class="DataLabel">{{ value.name }}</label>
        <span class="DataValue"> -->
            <!-- Auto-reflow to next line due to div -->
            <template v-if="isTable">
                
                <table class="table">
                    <thead>
                        <tr>
                            <th v-for="colname in columnNames" v-bind:key="colname" scope="col">{{ colname }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="row in value">
                            <td v-for="col in row">
                                <Result-View v-bind:value="col.value"></Result-View>
                            </td>
                        </tr>
                    </tbody>
                </table>

            </template>
            <template v-else-if="isArrResult">
                <ul class="list-group">
                    <Result-View v-for="val in value" v-bind:value="val"></Result-View>
                </ul>
            </template>
            <template v-else>
                {{ asStr }}
            </template>
        <!-- </span> -->
    </div>


</template>

<script lang="ts">
import Vue from "vue";
import * as util from '../utils';
import * as constants from '../constants';

export default Vue.component('ResultView', {
    name: 'ResultView',
    props: ['value'],
    computed: {
        isTable: function() : boolean {
            return (util.detectType(this.value) === constants.TYPE_ARRAY
             && this.value.length > 0 && util.detectType(this.value[0]) === constants.TYPE_ARRAY    // Has a row
             && this.value[0].length > 0 && util.detectType(this.value[0][0]) === constants.TYPE_OBJECT // Has atleast a column.
            ); 
        },
        columnNames: function() {
            // Extract column names from first row. Assume all rows follow same schema.
            return this.value[0].map((row) => row.key);
        },
        isArrResult: function() : boolean {
            return util.detectType(this.value) == constants.TYPE_ARRAY;
        },
        valType: function() : string {
            return util.detectType(this.value);
        },
        asStr: function() : string {
            return util.formatValue(this.value);
        }
    }
});
</script>

<style>
</style>
